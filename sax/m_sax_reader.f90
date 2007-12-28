module m_sax_reader

  ! This module implements a reader for XML documents.
  ! That is, functionally, it simply takes care of new-line
  ! handling, such that all newlines are converted to ASCII 0xA
  ! according to the algorithm in s2.11 of XML 1.0 or 1.1

  ! It offers several shortcut functions for seeking through
  ! the file for particular sequences of characters useful
  ! for XML parsing.

  ! It also offers the ability to push characters back into 
  ! the reader, onto a stack of additional buffers, which
  ! we need for entity expansion.

  ! Furthermore, readahead and pushback is available on
  ! all buffers.

  use m_common_array_str, only: vs_str_alloc, vs_vs_alloc
  use m_common_error,  only: error_stack, FoX_error
  use m_common_format, only: operator(//)
  use m_common_io, only: setup_io, io_eof, get_unit

  use m_sax_xml_source, only: xml_source_t, buffer_t, &
    get_char_from_file, push_file_chars, parse_xml_declaration

  implicit none
  private

  type file_buffer_t
    !FIXME private
    type(xml_source_t), pointer :: f(:) => null()
    type(buffer_t),  pointer  :: buffer_stack(:) => null()  ! stack of expansion buffers
    character, pointer        :: namebuffer(:) => null()    ! temporary buffer for retrieving strings
    logical                   :: standalone = .false.
  end type file_buffer_t

  public :: file_buffer_t
  public :: line
  public :: column

  public :: open_file
  public :: close_file

  public :: push_chars

  public :: get_character

  public :: push_buffer_stack
  public :: pop_buffer_stack

contains

  subroutine open_file(fb, iostat, file, lun, string, es)
    type(file_buffer_t), intent(out)  :: fb
    character(len=*), intent(in), optional :: file
    integer, intent(out)              :: iostat
    integer, intent(in), optional     :: lun
    character(len=*), intent(in), optional :: string
    type(error_stack), intent(inout) :: es

    iostat = 0

    call setup_io()
    allocate(fb%f(1))
    print*,"fb1 allocated"
    if (present(string)) then
      if (present(file)) then
        call FoX_error("Cannot specify both file and string input to open_xml")
      elseif (present(lun)) then
        call FoX_error("Cannot specify lun for string input to open_xml")
      endif
      call open_string_as_file(fb%f(1), string)
    else
      call open_actual_file(fb%f(1), file, iostat, lun)
      if (iostat/=0) return
    endif

    allocate(fb%buffer_stack(0))

  end subroutine open_file

  subroutine open_string_as_file(f, string)
    type(xml_source_t), intent(out)    :: f
    character(len=*), intent(in)     :: string

    f%lun = -1
    f%input_string%s => vs_str_alloc(string)
    f%filename => vs_str_alloc("")

    f%line = 1
    f%col = 0
    allocate(f%next_chars(0))
  end subroutine open_string_as_file

  subroutine open_actual_file(f, file, iostat, lun)
    type(xml_source_t), intent(out)    :: f
    character(len=*), intent(in)     :: file
    integer, intent(out)             :: iostat
    integer, intent(in), optional    :: lun

    if (present(lun)) then
      f%lun = lun
    else
      call get_unit(f%lun, iostat)
      if (iostat/=0) return
    endif
    open(unit=f%lun, file=file, form="formatted", status="old", &
      action="read", position="rewind", iostat=iostat)
    if (iostat/=0) return
    f%filename => vs_str_alloc(file)

    f%line = 1
    f%col = 0
    allocate(f%next_chars(0))
  end subroutine open_actual_file

  subroutine close_file(fb)
    type(file_buffer_t), intent(inout)  :: fb

    integer :: i

    if (fb%f(1)%lun/=-2) then
      if (associated(fb%namebuffer)) deallocate(fb%namebuffer)
      do i = 1, size(fb%buffer_stack)
        deallocate(fb%buffer_stack(i)%s)
      enddo
      deallocate(fb%buffer_stack)
      call close_actual_file(fb%f(1))
      deallocate(fb%f)
    endif

  end subroutine close_file

  subroutine close_actual_file(f)
    type(xml_source_t), intent(inout)    :: f

    if (f%lun/=-1) then
      close(f%lun)
    else
      deallocate(f%input_string%s)
      deallocate(f%input_string)
    endif
    deallocate(f%filename)

    f%line = 0
    f%col = 0
    deallocate(f%next_chars)
  end subroutine close_actual_file


  subroutine push_chars(fb, s)
    type(file_buffer_t), intent(inout) :: fb
    character(len=*), intent(in) :: s

    call push_file_chars(fb%f(1), s)

  end subroutine push_chars


  subroutine push_buffer_stack(fb, string)
    type(file_buffer_t), intent(inout) :: fb
    character(len=*), intent(in) :: string

    ! Add a new buffer to the stack.
    integer :: i
    type(buffer_t), dimension(:), pointer :: tempStack

    allocate(tempStack(size(fb%buffer_stack)+1))
    do i = 1, size(fb%buffer_stack)
      tempStack(i+1)%s => fb%buffer_stack(i)%s
      tempStack(i+1)%pos = fb%buffer_stack(i)%pos
    enddo
    tempStack(1)%s => vs_str_alloc(string)
    deallocate(fb%buffer_stack)
    fb%buffer_stack => tempStack
  end subroutine push_buffer_stack

  subroutine pop_buffer_stack(fb)
    type(file_buffer_t), intent(inout) :: fb

    ! Pop active buffer from the stack.
    integer :: i
    type(buffer_t), dimension(:), pointer :: tempStack

    deallocate(fb%buffer_stack(1)%s)
    allocate(tempStack(size(fb%buffer_stack)-1))
    do i = 1, size(tempStack)
      tempStack(i)%s => fb%buffer_stack(i+1)%s
      tempStack(i)%pos = fb%buffer_stack(i+1)%pos
    enddo
    deallocate(fb%buffer_stack)
    fb%buffer_stack => tempStack

  end subroutine pop_buffer_stack

  function get_character(fb, iostat, es) result(string)
    type(file_buffer_t), intent(inout) :: fb
    integer, intent(out) :: iostat
    type(error_stack), intent(inout) :: es
    character(len=1) :: string

    type(xml_source_t), pointer :: f
    type(buffer_t), pointer :: cb
    character, pointer :: temp(:)

    f => fb%f(1)

    if (size(f%next_chars)>0) then
      string = f%next_chars(1)
      if (size(f%next_chars)>1) then
        temp => vs_vs_alloc(f%next_chars(2:))
      else
        temp => vs_str_alloc("")
      endif
      deallocate(f%next_chars)
      f%next_chars => temp
      iostat = 0
    else
      ! Where are we reading from?
      if (size(fb%buffer_stack) > 0) then
        ! We are reading from an internal character buffer.
        cb => fb%buffer_stack(1)
        if (cb%pos<=size(cb%s)) then
          string = cb%s(cb%pos)
          cb%pos = cb%pos + 1
          iostat = 0 
        else
          ! Not enough characters here
          string = ''
          ! put characters back on putchar? FIXME
          iostat = io_eof
          return
        endif
      else
        ! We are reading from a file
        string = get_char_from_file(f, iostat, es)
        if (iostat/=0) return ! EOF or Error.
      endif
    endif

  end function get_character


  function line(fb) result(n)
    type(file_buffer_t), intent(in) :: fb
    integer :: n

    n = fb%f(1)%line
  end function line


  function column(fb) result(n)
    type(file_buffer_t), intent(in) :: fb
    integer :: n

    n = fb%f(1)%col
  end function column


end module m_sax_reader

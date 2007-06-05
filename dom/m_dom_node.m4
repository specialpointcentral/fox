include(`m_dom_exception.m4')`'dnl
TOHW_m_dom_imports(`

  use m_common_array_str, only: str_vs, vs_str_alloc
  use m_dom_error, only: DOMException, throw_exception, is_in_error, &
    NO_MODIFICATION_ALLOWED_ERR, NOT_FOUND_ERR, HIERARCHY_REQUEST_ERR, &
    WRONG_DOCUMENT_ERR

')`'dnl
dnl
TOHW_m_dom_publics(`
  
  public :: getNodeName
  public :: getNodevalue	
  public :: setNodeValue
  public :: getNodeType
  public :: getParentNode
  public :: getChildNodes
  public :: getFirstChild
  public :: getLastChild
  public :: getNextSibling
  public :: getPreviousSibling
  public :: getAttributes
  public :: getOwnerDocument
  public :: insertBefore
  public :: replaceChild
  public :: removeChild
  public :: appendChild
  public :: hasChildNodes
  public :: cloneNode  
  public :: normalize
  public :: isSupported
  public :: getNamespaceURI
  public :: getPrefix
  public :: setPrefix
  public :: getLocalName
  public :: hasAttributes
!  public :: isSameNode

')`'dnl
TOHW_m_dom_contents(`

  ! Getters and setters

  function getNodeName(arg) result(c)
    type(Node), intent(in) :: arg
    character(len=size(arg%nodeName)) :: c
    
    c = str_vs(arg%nodeName)
  end function getNodeName

  function getNodeValue(arg) result(c)
    type(Node), intent(in) :: arg
    character(len=size(arg%nodeName)) :: c
    
    c = str_vs(arg%nodeName)
  end function getNodeValue
  
  TOHW_subroutine(setNodeValue, (arg, nodeValue))
    type(Node), intent(inout) :: arg
    character(len=*) :: nodeValue

    if (arg%readonly) then
      TOHW_m_dom_throw_error(NO_MODIFICATION_ALLOWED_ERR)
    endif
      
    !FIXME check what kind of node is it, what is nodeValue allowed to be ...
    ! if it is an attribute node we need to reset TEXT/ENTITYREF children.

    deallocate(arg%nodeValue)
    arg%nodeValue => vs_str_alloc(nodeValue)
  end subroutine setNodeValue

  function getNodeType(arg) result(n)
    type(Node), intent(in) :: arg
    integer :: n

    n = arg%nodeType
  end function getNodeType

  function getParentNode(arg) result(np)
    type(Node), intent(in) :: arg
    type(Node), pointer :: np

    np => arg%parentNode
  end function getParentNode
  
  function getChildNodes(arg) result(nl)
    type(Node), intent(in) :: arg
    type(NodeList), pointer :: nl

    nl => arg%childnodes
  end function getChildNodes
  
  function getFirstChild(arg) result(np)
    type(Node), intent(in) :: arg
    type(Node), pointer :: np

    np => arg%firstChild
  end function getFirstChild
  
  function getLastChild(arg) result(np)
    type(Node), intent(in) :: arg
    type(Node), pointer :: np

    np => arg%lastChild
  end function getLastChild

  function getPreviousSibling(arg) result(np)
    type(Node), intent(in) :: arg
    type(Node), pointer :: np

    np => arg%previousSibling
  end function getPreviousSibling
  
  function getNextSibling(arg) result(np)
    type(Node), intent(in) :: arg
    type(Node), pointer :: np

    np => arg%nextSibling
  end function getNextSibling

  function getAttributes(arg) result(nnm)
    type(Node), intent(in) :: arg
    type(NamedNodeMap), pointer :: nnm

! FIXME surely only if this is an element node?

    nnm = arg%attributes
  end function getAttributes

  function getOwnerDocument(arg) result(np)
    type(Node), intent(in) :: arg
    type(Node), pointer :: np

    np => arg%ownerDocument
  end function getOwnerDocument

  TOHW_function(insertBefore, (arg, newChild, refChild))
    type(Node), pointer :: arg
    type(Node), pointer :: newChild
    type(Node), pointer :: refChild
    type(Node), pointer :: insertBefore

    type(Node), pointer :: np

    if (arg%readonly) then
      TOHW_m_dom_throw_error(NO_MODIFICATION_ALLOWED_ERR)
    endif
    
!   FIXME what about this next?
    if (.not. associated(arg)) call dom_error("insertBefore",0,"Node not allocated")

! FIXME need to special case this for inserting documentElement and documentType on document nodes
    select case(arg%nodeType)
    case (ELEMENT_NODE)
      if (newChild%nodeType/=ELEMENT_NODE &
        .and. newChild%nodeType/=TEXT_NODE &
        .and. newChild%nodeType/=COMMENT_NODE &
        .and. newChild%nodeType/=PROCESSING_INSTRUCTION_NODE &
        .and. newChild%nodeType/=CDATA_SECTION_NODE &
        .and. newChild%nodeType/=ENTITY_REFERENCE_NODE) &
        TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    case (ATTRIBUTE_NODE)
      if (newChild%nodeType/=TEXT_NODE &
        .and. newChild%nodeType/=ENTITY_REFERENCE_NODE) &
        TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    case (DOCUMENT_NODE)
      if (newChild%nodeType/=ELEMENT_NODE &
        .and. newChild%nodeType/=PROCESSING_INSTRUCTION_NODE &
        .and. newChild%nodeType/=COMMENT_NODE &
        .and. newChild%nodeType/=DOCUMENT_TYPE_NODE) &
        TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    case (DOCUMENT_FRAGMENT_NODE)
      if (newChild%nodeType/=ELEMENT_NODE &
        .and. newChild%nodeType/=TEXT_NODE &
        .and. newChild%nodeType/=COMMENT_NODE &
        .and. newChild%nodeType/=PROCESSING_INSTRUCTION_NODE &
        .and. newChild%nodeType/=CDATA_SECTION_NODE &
        .and. newChild%nodeType/=ENTITY_REFERENCE_NODE) &
        TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    case default
      TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    end select

    if (.not.associated(arg%ownerDocument, newChild%ownerDocument)) then
      TOHW_m_dom_throw_error(WRONG_DOCUMENT_ERR)
    endif
    
    if (.not.associated(refChild)) then
      insertBefore => appendChild(arg, newChild)
      return
    endif
    
    np => arg%firstChild
    do while (associated(np))
      if (associated(np, refChild)) then
        if (associated(np, arg%firstChild)) then
          arg%firstChild => newChild
        else
          np%previousSibling%nextSibling => newChild
        endif
        refChild%previousSibling => newChild
        newChild%nextSibling => refChild
        newChild%parentNode => arg
        insertBefore => newChild
        return
      endif
      np => np%nextSibling
    enddo

    TOHW_m_dom_throw_error(NOT_FOUND_ERR)

  end function insertBefore
  

  TOHW_function(replaceChild, (arg, newChild, oldChild))
    type(Node), pointer :: arg
    type(Node), pointer :: newChild
    type(Node), pointer :: oldChild
    type(Node), pointer :: replaceChild

    type(Node), pointer :: np
    
    if (arg%readonly) then
      TOHW_m_dom_throw_error(NO_MODIFICATION_ALLOWED_ERR)
    endif

    if (.not. associated(arg)) call dom_error("replaceChild",0,"Node not allocated")

    select case(arg%nodeType)
    case (ELEMENT_NODE)
      if (newChild%nodeType/=ELEMENT_NODE &
        .and. newChild%nodeType/=TEXT_NODE &
        .and. newChild%nodeType/=COMMENT_NODE &
        .and. newChild%nodeType/=PROCESSING_INSTRUCTION_NODE &
        .and. newChild%nodeType/=CDATA_SECTION_NODE &
        .and. newChild%nodeType/=ENTITY_REFERENCE_NODE) &
        TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    case (ATTRIBUTE_NODE)
      if (newChild%nodeType/=TEXT_NODE &
        .and. newChild%nodeType/=ENTITY_REFERENCE_NODE) &
        TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    case (DOCUMENT_NODE)
      if (newChild%nodeType/=ELEMENT_NODE &
        .and. newChild%nodeType/=PROCESSING_INSTRUCTION_NODE &
        .and. newChild%nodeType/=COMMENT_NODE &
        .and. newChild%nodeType/=DOCUMENT_TYPE_NODE) &
        TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    case (DOCUMENT_FRAGMENT_NODE)
      if (newChild%nodeType/=ELEMENT_NODE &
        .and. newChild%nodeType/=TEXT_NODE &
        .and. newChild%nodeType/=COMMENT_NODE &
        .and. newChild%nodeType/=PROCESSING_INSTRUCTION_NODE &
        .and. newChild%nodeType/=CDATA_SECTION_NODE &
        .and. newChild%nodeType/=ENTITY_REFERENCE_NODE) &
        TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    case default
      TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    end select

    if (.not.associated(arg%ownerDocument, newChild%ownerDocument)) then
      TOHW_m_dom_throw_error(WRONG_DOCUMENT_ERR)
    endif

    np => arg%firstChild

    do while (associated(np))    
       if (associated(np, oldChild)) then
          if (associated(np, arg%firstChild)) then
             arg%firstChild => newChild
             if (associated(np%nextSibling)) then
                np%nextSibling%previousSibling => newChild
             else
                arg%lastChild => newChild    ! there was just 1 node
             endif
          elseif (associated(np, arg%lastChild)) then
             ! one-node-only case covered above
             arg%lastChild => newChild
             np%previousSibling%nextSibling => newChild
          else
             np%previousSibling%nextSibling => newChild
             np%nextSibling%previousSibling => newChild
          endif
          newChild%parentNode => arg
          newChild%nextSibling => oldChild%nextSibling
          newChild% previousSibling => oldChild%previousSibling
          replaceChild => oldChild
          return
       endif
       np => np%nextSibling
    enddo

    TOHW_m_dom_throw_error(NOT_FOUND_ERR)

  end function replaceChild


  TOHW_function(removeChild, (arg, oldChild))
    type(Node), pointer :: removeChild
    type(Node), pointer :: arg
    type(Node), pointer :: oldChild
    type(Node), pointer :: np
    
    if (arg%readonly) then
      TOHW_m_dom_throw_error(NO_MODIFICATION_ALLOWED_ERR)
    endif

    if (.not.associated(arg)) call dom_error("removeChild",0,"Node not allocated")
    np => arg%firstChild
    
    do while (associated(np))
      if (associated(np, oldChild)) then
        if (associated(np, arg%firstChild)) then
          arg%firstChild => np%nextSibling
          if (associated(np%nextSibling)) then
            arg%firstChild%previousSibling => null()
          else
            arg%lastChild => null()    ! there was just 1 node
          endif
        else if (associated(np, arg%lastChild)) then
          ! one-node-only case covered above
          arg%lastChild => np%previousSibling
          np%lastChild%nextSibling => null()
        else
          np%previousSibling%nextSibling => np%nextSibling
          np%nextSibling%previousSibling => np%previousSibling
        endif
        arg%nc = arg%nc -1
        np%previousSibling => null()    ! Are these necessary?
        np%nextSibling => null()
        np%parentNode => null()
        removeChild => oldChild
        return
      endif
      np => np%nextSibling
    enddo
    
    TOHW_m_dom_throw_error(NOT_FOUND_ERR)

  end function removeChild


  TOHW_function(appendChild, (arg, newChild))
    type(Node), pointer :: arg
    type(Node), pointer :: newChild
    type(Node), pointer :: appendChild
    
    if (arg%readonly) then
      TOHW_m_dom_throw_error(NO_MODIFICATION_ALLOWED_ERR)
    endif

    if (.not. associated(arg))  & 
      call dom_error("appendChild",0,"Node not allocated")
    
    select case(arg%nodeType)
    case (ELEMENT_NODE)
      if (newChild%nodeType/=ELEMENT_NODE &
        .and. newChild%nodeType/=TEXT_NODE &
        .and. newChild%nodeType/=COMMENT_NODE &
        .and. newChild%nodeType/=PROCESSING_INSTRUCTION_NODE &
        .and. newChild%nodeType/=CDATA_SECTION_NODE &
        .and. newChild%nodeType/=ENTITY_REFERENCE_NODE) &
        TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    case (ATTRIBUTE_NODE)
      if (newChild%nodeType/=TEXT_NODE &
        .and. newChild%nodeType/=ENTITY_REFERENCE_NODE) &
        TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    case (DOCUMENT_NODE)
      if (newChild%nodeType/=ELEMENT_NODE &
        .and. newChild%nodeType/=PROCESSING_INSTRUCTION_NODE &
        .and. newChild%nodeType/=COMMENT_NODE &
        .and. newChild%nodeType/=DOCUMENT_TYPE_NODE) &
        TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    case (DOCUMENT_FRAGMENT_NODE)
      if (newChild%nodeType/=ELEMENT_NODE &
        .and. newChild%nodeType/=TEXT_NODE &
        .and. newChild%nodeType/=COMMENT_NODE &
        .and. newChild%nodeType/=PROCESSING_INSTRUCTION_NODE &
        .and. newChild%nodeType/=CDATA_SECTION_NODE &
        .and. newChild%nodeType/=ENTITY_REFERENCE_NODE) &
        TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    case default
      TOHW_m_dom_throw_error(HIERARCHY_REQUEST_ERR)
    end select

    if (.not.associated(arg%ownerDocument, newChild%ownerDocument)) then
      TOHW_m_dom_throw_error(WRONG_DOCUMENT_ERR)
    endif
    
    if (.not.(associated(arg%firstChild))) then
      arg%firstChild => newChild
    else 
      newChild%previousSibling => arg%lastChild
      arg%lastChild%nextSibling => newChild 
    endif
    
    arg%lastChild => newChild
    newChild%parentNode => arg
    arg%nc = arg%nc + 1
    
    appendChild => newChild
    
  end function appendChild


  function hasChildNodes(arg)
    type(Node), pointer :: arg
    logical :: hasChildNodes
    
    if (.not. associated(arg)) call dom_error("hasChildNodes",0,"Node not allocated")
    hasChildNodes = associated(arg%firstChild)
    
  end function hasChildNodes

  function cloneNode(arg, deep) result(np)
    type(Node), pointer :: arg
    logical :: deep
    type(Node), pointer :: np

    type(Node), pointer :: np_a1, np_a2, this, that, new, ERchild
    type(NamedNodeMap), pointer :: nnm

    logical :: noChild, readonly
    integer :: i

    noChild = .false.
    readonly = .false.
    
    ERchild => null()
    this => arg
    do
      if (noChild) then
        if (associated(this, arg)) exit
        if (associated(this, ERchild)) then
          ! Weve got back up to the top of the topmost ER.
          readonly = .false.
          ERchild => null()
        endif
        if (associated(this%nextSibling)) then
          this => this%nextSibling
          noChild = .false.
        else
          this => this%parentNode
          that => that%parentNode
          cycle
        endif
      endif
      select case(this%nodeType)
        case (ELEMENT_NODE)
          new => createElementNS(this%ownerDocument, &
            str_vs(this%namespaceURI), str_vs(this%localName))
          ! loop over attributes cloning them
          nnm => getAttributes(this)
          do i = 1, getLength(nnm)
            np_a1 => item(nnm, i)
            np_a2 => createAttributeNS(this%ownerDocument, &
              str_vs(np_a1%namespaceURI), str_vs(np_a1%localName))
            call setValue(new, getValue(np_a1))
            call setSpecified(np_a2, np_a1%specified)
            np_a2 => setAttributeNodeNS(np, np_a2)
          end do
        case (ATTRIBUTE_NODE)
          new => createAttributeNS(this%ownerDocument, &
            str_vs(this%namespaceURI), str_vs(this%localName))
          call setValue(new, getValue(np_a2))
          call setSpecified(new, .true.)
        case (TEXT_NODE)
          new => createTextNode(this%ownerDocument, str_vs(this%nodeValue))
        case (CDATA_SECTION_NODE)
          new => createCdataSection(this%ownerDocument, str_vs(this%nodeValue))
        case (ENTITY_REFERENCE_NODE)
          new => createEntityReference(this%ownerDocument, str_vs(this%nodeName))
          ERChild => this
        case (ENTITY_NODE)
          new => null()
        case (PROCESSING_INSTRUCTION_NODE)
          new => createProcessingInstruction(this%ownerDocument, &
            str_vs(this%nodeName), str_vs(this%nodeValue))
        case (COMMENT_NODE)
          new => createComment(this%ownerDocument, str_vs(this%nodeValue))
        case (DOCUMENT_NODE)
          new => null()
        case (DOCUMENT_FRAGMENT_NODE)
          new => createDocumentFragment(this%ownerDocument)
        case (NOTATION_NODE)
          new => null()
        end select
        if (readonly) then
          that%readonly = .true.
        elseif (associated(ERChild)) then
          readonly = .true.
        endif
        if (associated(this, arg)) then
          that => new
          if (.not.deep) exit
        else
          new => appendChild(that, new)
        endif
        if (associated(this%firstChild)) then
          this => this%firstChild
          if (.not.associated(this, arg)) then
            that => that%lastChild
            !FIXME logic
          endif
        else
          noChild = .true.
        endif
      enddo

      np => that

  end function cloneNode

  
  function hasAttributes(arg)
    type(Node), pointer :: arg
    logical :: hasAttributes
    
    if (.not.associated(arg)) call dom_error("hasAttributes",0,"Node not allocated")
    hasAttributes = (arg%nodeType /= ELEMENT_NODE) &
      .and. (arg%attributes%list%length > 0)
    
  end function hasAttributes
  
  subroutine normalize(arg)
    type(Node), intent(inout) :: arg
    
    ! FIXME implement
  end subroutine normalize

  function isSupported(arg, feature, version) result(p)
    type(Node), intent(in) :: arg
    character(len=*), intent(in) :: feature
    character(len=*), intent(in) :: version
    logical :: p

    ! FIXME implement
    p = .true.
  end function isSupported

  ! FIXME should the below instead just decompose the QName on access?
  function getNamespaceURI(arg) result(c)
    type(Node), intent(in) :: arg
    character(len=size(arg%namespaceURI)) :: c

    c = str_vs(arg%namespaceURI)
  end function getNamespaceURI

  function getPrefix(arg) result(c)
    type(Node), intent(in) :: arg
    character(len=size(arg%prefix)) :: c

    c = str_vs(arg%prefix)
  end function getPrefix
  
  subroutine setPrefix(arg, prefix)
    type(Node), intent(inout) :: arg
    character(len=*) :: prefix

    deallocate(arg%prefix)
    arg%prefix => vs_str_alloc(prefix)
  end subroutine setPrefix

  function getLocalName(arg) result(c)
    type(Node), intent(in) :: arg
    character(len=size(arg%localName)) :: c

    c = str_vs(arg%localName)
  end function getLocalName

  function isSameNode(node1, node2)    ! DOM 3.0
    type(Node), pointer :: node1
    type(Node), pointer :: node2
    logical :: isSameNode

    isSameNode = associated(node1, node2)

  end function isSameNode

')`'dnl

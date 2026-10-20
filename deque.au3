#include-once


#include "mydebug.au3"

#cs
--- Double Ended Queue, Single Ended Queue (FIFO), and Stack (LIFO) Functions ---


--- Stack
__StackNew()                     		create a new 'stack' object (its same as deque)
__StackPop($oDeque)                     stack push
__StackPush($oDeque, $vItem)            stack pop
__StackIsEmpty($oDeque)                 is stack empty


--- Single Ended Queue
__QueueNew()                     		create a new 'queue' object (its same as deque)
__QueuePop($oDeque)                     single ended queue push
__QueuePush($oDeque, $vItem)            single ended queue pop
__QueueIsEmpty($oDeque)                 is queue empty


--- Double Ended Queue
__DequeNew()                     		create a new deque object
__DequeIsDeque($oDeque)                 validate if object is a queue
__DequePush($oDeque, $vItem)            push item into back of queue
__DequePushFront($oDeque, $vItem)       push item into front of queue
__DequePop($oDeque)                     pop item from front of queue
__DequePopBack($oDeque)                 pop item from back of queue
__DequePeek($oDeque)                    peek at item in front of queue
__DequePeakBack($oDeque)                peek at item in back of queue
__DequeSize($oDeque)                    get number of items in queue
__DequeIsEmpty($oDeque)                 is the queue empty


--- Double Ended Queue additional functions
__DequePushQue($oDeque, $oQue)          push entire Deque $oQue into $oDeque
__DequePushFrontQue($oDeque, $oQue)     push entire Deque $oQue into front of $oDeque
__DequePopQue($oDeque)                  pop entire queue
__DequePopBackQue($oDeque)              pop entire queue from back instead of front
__DequePeekQue($oDeque)                 peek at entire queue

__DequeCopy($oDeque)					create new copy of oDeque
__DequeCopyReverse($oDeque)				create a new copy of oDeque but reverse the order of the contents

__DequeToArray($oDeque)                 copy oDeque to an array


--- Program Queue to hold statement/instruction block
__pQueNew($sCmd = "", $sCond = "")      create new pQue
__pQuePush($opQue, $vItem)              pQue push
__pQuePop($opQue)                       pQue pop
__pQueIsEmpty($opQue)                   pQue is empty
__pQuePC($opQue)                        get PC index from pQue
__pQueIsParked($opQue)                  return true if PC is 'parked', pc < head.  this signals us the queue is not being processed at the moment
__pQueRelease($opQue)                   move PC to head of queue to 'unpark' it so that it is processed on next encounter
__pQueIsStart($opQue)                   return true if the PC is at the front of the queue, we are just starting to process the queue
__pQueIsDone($opQue)                    return true if PC is past the tail, indicating we finished processing the queue
__pQueSetDone($opQue)                   set PC to past the end of the queue to indicate done processing
__pQueRestart($opQue)                   set PC to head to restart processing the queue
__pQueIncPC($opQue)                     increment PC.  if PC at end of queue then stop at one past the end
__pQuePCitem($opQue)                    return the item currently indexed by the PC
__pQueCond($opQue)                      return the cond field
__pQueSetCond($opQue, $vCond)           set the cond field
__pQueCmd($opQue)                       return the cmd field
__pQueSetCmd($opQue, $vCmd)             set the cmd field
__pQueSet($opQue, $vCmd, $vCond)        set both cmd and cond fields
__pQueSkip($opQue, $bFlag = "")         set or get the skip flag


#ce




;---------------------------------------------------------------------- DE Queue


Func __DequeConstruct()                                                 ; create new DeQue object
	Local $oDeque = ObjCreate("Scripting.Dictionary")
	$oDeque.Item("head") = 1                                                ; Points to the item at the head
	$oDeque.Item("tail") = 0                                                ; Points to the item at the tail
	Return $oDeque
EndFunc   ;==>__DequeConstruct
Func __DequeNew()
	Return __DequeConstruct()
EndFunc   ;==>__DequeNew

Func __DequeDestruct($oDeque)                                           ; destruct DeQue object to save memeory
	$oDeque.Remove("head")
	$oDeque.Remove("tail")
	$oDeque = Null
EndFunc   ;==>__DequeDestruct

Func __DequeIsDeque($oDeque)                                            ; validate if object is a queue
	If Not IsObj($oDeque) Then Return False
	If ObjName($oDeque) <> "Dictionary" Then Return False
	If Not $oDeque.Exists("head") Then Return False
	If Not $oDeque.Exists("tail") Then Return False
	Return True
EndFunc   ;==>__DequeIsDeque

Func __DequePush($oDeque, $vItem)                                       ; push item into back of queue
	If Not __DequeIsDeque($oDeque) Then Return SetError(1, 0, 0)
	__DequeCheckTailLimit($oDeque)
	Local $iTail = $oDeque.Item("tail") + 1                                 ; move tail forward
	$oDeque.Item("tail") = $iTail                                           ;
	$oDeque.Item(String($iTail)) = $vItem                                   ; Store item under stringified index
	Return 1
EndFunc   ;==>__DequePush

Func __DequePushFront($oDeque, $vItem)                                  ; push item into front of queue
	If Not __DequeIsDeque($oDeque) Then Return SetError(1, 0, 0)
	__DequeCheckHeadLimit($oDeque)
	Local $iHead = $oDeque.Item("head") - 1                                 ; move head backward
	$oDeque.Item("head") = $iHead                                           ;
	$oDeque.Item(String($iHead)) = $vItem                                   ; Store item under stringified index
	Return 1
EndFunc   ;==>__DequePushFront

Func __DequePop($oDeque)                                                ; pop item from front of queue
	If Not __DequeIsDeque($oDeque) Then Return SetError(-1, 0, 0)
	Local $iHead = $oDeque.Item("head")
	Local $iTail = $oDeque.Item("tail")
	If $iHead > $iTail Then Return SetError(-2, 0, 0)                       ; Deque is completely empty
	Local $sKey = String($iHead)
	Local $vItem = $oDeque.Item($sKey)
	$oDeque.Remove($sKey)                                                   ; Instantly clear memory footprint
	$oDeque.Item("head") = $iHead + 1                                       ; Move head forward
	Return $vItem
EndFunc   ;==>__DequePop

Func __DequePopBack($oDeque)                                            ; pop item from back of queue
	If Not __DequeIsDeque($oDeque) Then Return SetError(-1, 0, 0)
	Local $iHead = $oDeque.Item("head")
	Local $iTail = $oDeque.Item("tail")
	If $iHead > $iTail Then Return SetError(-2, 0, 0)                       ; Deque is completely empty
	Local $sKey = String($iTail)
	Local $vItem = $oDeque.Item($sKey)
	$oDeque.Remove($sKey)                                                   ; Instantly clear memory footprint
	$oDeque.Item("tail") = $iTail - 1                                       ; Move tail backwards
	Return $vItem
EndFunc   ;==>__DequePopBack

Func __DequePeek($oDeque)                                               ; peek at item in front of queue
	If Not __DequeIsDeque($oDeque) Then Return SetError(1, 0, 0)
	Local $iHead = $oDeque.Item("head")
	Local $iTail = $oDeque.Item("tail")
	If $iHead > $iTail Then Return SetError(2, 0, "")                       ; Deque is completely empty
	Return $oDeque.Item(String($iHead))
EndFunc   ;==>__DequePeek

Func __DequePeakBack($oDeque)                                           ; peek at item in back of queue
	If Not __DequeIsDeque($oDeque) Then Return SetError(1, 0, 0)
	Local $iHead = $oDeque.Item("head")
	Local $iTail = $oDeque.Item("tail")
	If $iHead > $iTail Then Return SetError(2, 0, "")                       ; Deque is completely empty
	Return $oDeque.Item(String($iTail))
EndFunc   ;==>__DequePeakBack

Func __DequeSize($oDeque)                                               ; get number of items in queue
	If Not __DequeIsDeque($oDeque) Then Return SetError(1, 0, 0)
	Return $oDeque.Item("tail") - $oDeque.Item("head") + 1
EndFunc   ;==>__DequeSize

Func __DequeIsEmpty($oDeque)                                            ; is the queue empty
	If Not __DequeIsDeque($oDeque) Then Return SetError(1, 0, True)
	Return $oDeque.Item("head") > $oDeque.Item("tail")
EndFunc   ;==>__DequeIsEmpty


Func __DequeCheckTailLimit($oDeque)                                     ; check if iTail index number is reaching the limit for a 32-bit number and reseat if needed
	Local $iUpperLimit = 2147483640
	If $oDeque.Item("tail") < $iUpperLimit Then Return 0
	Local $iLowerLimit = -2147483640
	Local $iHead = $oDeque.Item("head")
	Local $iTail = $oDeque.Item("tail")
	Local $iDelta = 1 - $iHead
	If $iDelta > 0 Then $iDelta = $iLowerLimit - $iHead
	If $iDelta >= 0 Then Return SetError(-1, 0, 0)                      ; we have reached our limits, there may not be any more space in the queue
	For $i = $iHead To $iTail                                            ; moving from head to tail, move each index key backwards by $iDelta
		$oDeque.Key(String($i)) = $i + $iDelta
	Next
	$oDeque.Item("head") = $iHead + $iDelta
	$oDeque.Item("tail") = $iTail + $iDelta
	Return $iDelta                                                      ; return the delta for caller to use if needed
EndFunc   ;==>__DequeCheckTailLimit

Func __DequeCheckHeadLimit($oDeque)                                     ; check if iHead index number is reaching the limit for a negative 32-bit number and reseat if needed
	Local $iLowerLimit = -2147483640
	If $oDeque.Item("head") > $iLowerLimit Then Return 0
	Local $iUpperLimit = 2147483640
	Local $iHead = $oDeque.Item("head")
	Local $iTail = $oDeque.Item("tail")
	Local $iDelta = 1 - $iTail
	If $iDelta < 0 Then $iDelta = $iUpperLimit - $iTail
	If $iDelta <= 0 Then Return SetError(-1, 0, 0)                      ; we have reached our limits, there may not be any more space in the queue
	For $i = $iTail To $iHead Step -1                                   ; moving from tail to head, move each index key forward by $iDelta
		$oDeque.Key(String($i)) = $i + $iDelta
	Next
	$oDeque.Item("head") = $iHead + $iDelta
	$oDeque.Item("tail") = $iTail + $iDelta
	Return $iDelta                                                      ; return the delta for caller to use if needed
EndFunc   ;==>__DequeCheckHeadLimit



;---------------------------------------------------------------------- Stack (LIFO / FILO)


Func __StackNew()                                                       ; create new stack object (deque)
	Return __DequeNew()
EndFunc   ;==>__StackNew
Func __StackPush($oDeque, $vItem)                                       ; stack push
	Local $vR = __DequePushFront($oDeque, $vItem)

	#forcedef $g_viPrintpQue
	If $g_viPrintpQue Then
		__ConsoleWriteVar($vItem, ", ", "__StackPush")
		__ConsoleWriteVar($oDeque, ", ", "       into")
	EndIf

	Return $vR
EndFunc   ;==>__StackPush
Func __StackPop($oDeque)                                                ; stack pop
	Local $vItem = __DequePop($oDeque)

	#forcedef $g_viPrintpQue
	If $g_viPrintpQue Then
		__ConsoleWriteVar($vItem, ", ", "__StackPop ")
		__ConsoleWriteVar($oDeque, ", ", "    out of")
	EndIf

	Return $vItem
EndFunc   ;==>__StackPop
Func __StackIsEmpty($oDeque)                                            ; is stack empty
	Return __DequeIsEmpty($oDeque)
EndFunc   ;==>__StackIsEmpty
Func __StackPeek($oDeque)                                               ; peek at top item on the stack
	Return __DequePeek($oDeque)
EndFunc   ;==>__StackPeek




;---------------------------------------------------------------------- Queue (FIFO / LILO)


Func __QueueNew()                                                       ; create new single ended queue object (deque)
	Return __DequeNew()
EndFunc   ;==>__QueueNew
Func __QueuePop($oDeque)                                                ; single ended queue push
	Return __DequePop($oDeque)
EndFunc   ;==>__QueuePop
Func __QueuePush($oDeque, $vItem)                                       ; single ended queue pop
	Return __DequePush($oDeque, $vItem)
EndFunc   ;==>__QueuePush
Func __QueueIsEmpty($oDeque)                                            ; is queue empty
	Return __DequeIsEmpty($oDeque)
EndFunc   ;==>__QueueIsEmpty




;---------------------------------------------------------------------- DE Queue extended functions


Func __DequePushQue($oDeque, $oQue)                                     ; push entire Deque $oQue into $oDeque
	While Not __DequeIsEmpty($oQue)
		__DequePush($oDeque, __DequePop($oQue))
	WEnd
EndFunc   ;==>__DequePushQue

Func __DequePushFrontQue($oDeque, $oQue)                                ; push entire Deque $oQue into front of $oDeque
	While Not __DequeIsEmpty($oQue)
		__DequePushFront($oDeque, __DequePop($oQue))
	WEnd
EndFunc   ;==>__DequePushFrontQue

Func __DequePopQue($oDeque)                                             ; pop entire queue
	Local $oQue = $oDeque
	$oDeque = __DequeConstruct()
	Return $oQue
EndFunc   ;==>__DequePopQue

Func __DequePopBackQue($oDeque)                                         ; pop entire queue from back instead of front
	Local $oQue = __DequeConstruct()
	__DequePushFrontQue($oQue, $oDeque)
	Return $oQue
EndFunc   ;==>__DequePopBackQue

Func __DequePeekQue($oDeque)                                            ; peek at entire queue
	Return $oDeque
EndFunc   ;==>__DequePeekQue

Func __DequeToArray($oDeque)                                            ; copy oDeque to an array
	Local $a[0]
	If Not __DequeIsDeque($oDeque) Then Return $a
	Local $iHead = $oDeque.Item("head")
	Local $iTail = $oDeque.Item("tail")
	Local $iSize = $iTail - $iHead + 1
	If $iSize <= 0 Then Return $a
	Local $i
	redim $a[$iSize]
	For $i = $iHead To $iTail
		$a[$i-$iHead] = $oDeque.Item(String($i))
	Next
	Return $a
EndFunc   ;==>__DequeToArray

Func __DequeCopy($oDeque)                                               ; make a copy of oDeque
	Local $oQue = __DequeConstruct()
	If Not __DequeIsDeque($oDeque) Then Return $oQue
	Local $sKey
	For $sKey In $oDeque
		$oQue.Item($sKey) = $oDeque.Item($sKey)
	Next
	Return $oQue
EndFunc   ;==>__DequeCopy

Func __DequeCopyReverse($oDeque)                                        ; make a copy of oDeque but reverse the order of the items
	Local $oQue = __DequeConstruct()
	If Not __DequeIsDeque($oDeque) Then Return $oQue
	Local $i, $N = $oDeque.Item("tail")
	For $i = $oDeque.Item("head") To $N
		__DequePushFront($oQue, $oDeque.Item(String($i)))
	Next
	Return $oQue
EndFunc   ;==>__DequeCopyReverse




;---------------------------------------------------------------------- program instruction block queue


Func __pQueNew($sCmd = "", $sCond = "", $bCond = False)                 ; create new pQue
	Local $opQue = __DequeConstruct()
	$opQue.Item("pc") = 0                                               ; set PC = Head - 1 to signal we are 'parked' (not (re)processing the queue, just pushing items into it)
	$opQue.Item("cmd") = $sCmd                                          ; flow control command for this command block (until,while,if)
	$opQue.Item("cond") = $sCond                                        ; loop or if condition for this command block
	$opQue.Item("bCond") = $bCond                                       ; result of the evaluated cond
	$opQue.Item("skip") = False                                         ; when processing command for the first time in a command block, if a prior if statement evaled to false, need to not execute the commands, but continue to add them to the block
	Return $opQue
EndFunc   ;==>__pQueNew

Func __pQuePush($opQue, $vItem)                                         ; pQue push
	If Not __DequeIsDeque($opQue) Then Return False
	Local $iDelta = __DequeCheckTailLimit($opQue)
	If $iDelta Then $opQue.Item("pc") = $opQue.Item("pc") + $iDelta     ; if queue is reseated then adjust 'pc' to match
	Local $vR = __DequePush($opQue, $vItem)

	#forcedef $g_viPrintpQue
	If $g_viPrintpQue Then
		__ConsoleWriteVar($vItem, ", ", "__pQuePush")
		__ConsoleWriteVar($opQue, ", ", "      into")
	EndIf

	Return $vR
EndFunc   ;==>__pQuePush

Func __pQuePop($opQue)                                                  ; pQue pop
	Local $vItem = __DequePop($opQue)

	#forcedef $g_viPrintpQue
	If $g_viPrintpQue Then
		__ConsoleWriteVar($vItem, ", ", "__pQuePop ")
		__ConsoleWriteVar($opQue, ", ", "    out of")
	EndIf

	Return $vItem
EndFunc   ;==>__pQuePop

Func __pQueIsEmpty($opQue)                                              ; pQue is empty
	Return __DequeIsEmpty($opQue)
EndFunc   ;==>__pQueIsEmpty

Func __pQuePC($opQue)                                                   ; get PC index from pQue
	If Not __DequeIsDeque($opQue) Then Return SetError(-1, 0, -1)       ;   return -1, @error=-1 if input is not a queue object
	Local $i = $opQue.Item("pc")
	Local $iHead = $opQue.Item("head")
	Local $iTail = $opQue.Item("tail")
	If $i < $iHead Then Return SetError(1, 0, $iHead - 1)               ;   return @error=1 if queue is parked
	If $i > $iTail Then Return SetError(2, 0, $iTail + 1)               ;   return @error=2 if PC is past the end of the queue (finished)
	Return SetError($opQue.Exists(String($i)) ? 0 : -1, 0, $i)          ;   return index, @error=-1 if item at index is unexpectedly missing
EndFunc   ;==>__pQuePC

Func __pQueIsParked($opQue)                                             ; return true if PC is 'parked', pc < head.  this signals us the queue is not being processed at the moment
	If Not __DequeIsDeque($opQue) Then Return SetError(1, 0, False)
	Return $opQue.Item("pc") < $opQue.Item("head")
EndFunc   ;==>__pQueIsParked

Func __pQueRelease($opQue)                                              ; unpark the queue.  point pc at the head so when it is encountered again it gets processed from the start
	If Not __DequeIsDeque($opQue) Then Return SetError(1, 0, False)
	$opQue.Item("pc") = $opQue.Item("head")
	Return True
EndFunc   ;==>__pQueRelease

Func __pQueIsStart($opQue)                                              ; return true if the PC is at the front of the queue, we are just starting to process the queue
	If Not __DequeIsDeque($opQue) Then Return SetError(-1, 0, False)
	Return $opQue.Item("pc") = $opQue.Item("head")
EndFunc   ;==>__pQueIsStart

Func __pQueIsDone($opQue)                                               ; return true if PC is past the tail, indicating we finished processing the queue
	If Not __DequeIsDeque($opQue) Then Return SetError(-1, 0, True)
	Return $opQue.Item("pc") > $opQue.Item("tail")
EndFunc   ;==>__pQueIsDone

Func __pQueSetDone($opQue)                                              ; set PC to past the end of the queue to indicate done processing
	If Not __DequeIsDeque($opQue) Then Return SetError(1, 0, False)
	$opQue.Item("pc") = $opQue.Item("tail") + 1
	Return True
EndFunc   ;==>__pQueSetDone

Func __pQueRestart($opQue)                                              ; set PC to head to restart processing the queue
	If Not __DequeIsDeque($opQue) Then Return False
	$opQue.Item("pc") = $opQue.Item("head")
	Return True
EndFunc   ;==>__pQueRestart

Func __pQueIncPC($opQue)                                                ; increment PC.  if PC at end of queue then stop at one past the end
	If Not __DequeIsDeque($opQue) Then Return SetError(1, 0, False)     ;   if not a que then return false, @error=1
	Local $iHead = $opQue.Item("head")
	Local $iTail = $opQue.Item("tail")
	Local $i = $opQue.Item("pc")
	If $i <= $iTail Then $i += 1
	If $i < $iHead Then $i = $iHead
	$opQue.Item("pc") = $i
	Return $i <= $iTail                                                 ;   if past tail then return false, else return true
EndFunc   ;==>__pQueIncPC

Func __pQuePCitem($opQue)                                               ; return the item currently indexed by the PC
	Local $i = __pQuePC($opQue)
	If @error < 0 Then Return SetError(-1, 0, 0)                        ;   return 0 and @error=-1 if opQue is not a queue or item PC is point at is missing
	If @error > 0 Then Return SetError(@error, 0, 0)                    ;   if parked then, return 0 and @error=1,   or if done then return 0 and @error=2
	__pQueIncPC($opQue)                                                 ;   increment PC
	Local $vRet = $opQue.Item(String($i))                               ;   return the item (either an array (command) or queue object (command block) if all is well
	#forcedef $g_viPrintpQue
	If $g_viPrintpQue Then __ConsoleWriteVar($vRet, ", ", "pQue item")
	Return $vRet
EndFunc   ;==>__pQuePCitem

Func __pQueCond($opQue)                                                 ; return the cond field
	If Not __DequeIsDeque($opQue) Then Return SetError(1, 0, 0)
	Return $opQue.Item("cond")
EndFunc   ;==>__pQueCond

Func __pQueSetCond($opQue, $vCond)                                      ; set the cond field
	If Not __DequeIsDeque($opQue) Then Return SetError(1, 0, False)
	$opQue.Item("cond") = $vCond
	Return True
EndFunc   ;==>__pQueSetCond

Func __pQueCmd($opQue)                                                  ; return the cmd field
	If Not __DequeIsDeque($opQue) Then Return SetError(1, 0, 0)
	Return $opQue.Item("cmd")
EndFunc   ;==>__pQueCmd

Func __pQueSetCmd($opQue, $vCmd)                                        ; set the cmd field
	If Not __DequeIsDeque($opQue) Then Return SetError(1, 0, False)
	$opQue.Item("cmd") = $vCmd
	Return True
EndFunc   ;==>__pQueSetCmd

Func __pQueSet($opQue, $vCmd, $vCond = "", $bCond = False)              ; set both cmd and cond fields
	If Not __DequeIsDeque($opQue) Then Return SetError(1, 0, False)
	$opQue.Item("cmd") = $vCmd
	$opQue.Item("cond") = $vCond
	$opQue.Item("bCond") = $bCond
	Return True
EndFunc   ;==>__pQueSet

Func __pQueSkip($opQue, $bFlag = "")                                    ; set or get the skip flag
	If $bFlag <> "" Then $opQue.Item('skip') = $bFlag
	Return $opQue.Item('skip')
EndFunc   ;==>__pQueSkip


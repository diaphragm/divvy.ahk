#SingleInstance, Force
#MaxThreadsPerHotkey, 2
SendMode Input
SetWorkingDir, %A_ScriptDir%
SetWinDelay, 0

#include divvy.config.ahk

global rowSize
global colSize
global accentColor

global hwndControlWindowList := ""
global hwndResizeOverlay := ""
global hwndTargetOverlay:= ""
global hwndTargetWindow := ""
global elemFrom := 0
global elemTo := 0

; ========
; Util
; ========

; short circuit evaluation or
SOR(a, b){
  if(a)
    Return a
  else
    Return b
}

; Copy from WindowSpy.ahk
GetClientSize(hWnd, ByRef w := "", ByRef h := "")
{
  VarSetCapacity(rect, 16)
  DllCall("GetClientRect", "ptr", hWnd, "ptr", &rect)
  w := NumGet(rect, 8, "int")
  h := NumGet(rect, 12, "int")
}

WinMove2(hwnd, x, y, w, h){
  WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%
  GetClientSize(hwnd, cw, ch)
  dw := ww - cw
  dh := wh - ch

  fx := x - dw / 2
  fw := w + dw
  fy := y 
  fh := h + dh

  WinMove, ahk_id %hwnd%,, %fx%, %fy%, %fw%, %fh%
}

WinGetPos2(hwnd, ByRef x, ByRef y, ByRef w, ByRef h){
  WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%
  GetClientSize(hwnd, cw, ch)
  dw := ww - cw
  dh := wh - ch

  x := wx + dw / 2
  w := cw
  y := wy
  h := ch
}

; ========
; GUI
; ========

ShowTargetOverlay(){
  Gui, Color, %accentColor%
  Gui, +AlwaysOnTop -Caption
  Gui, +HwndhwndTargetOverlay
  Gui, +LastFound
  WinSet, Transparent, 64

  Gui, Show, x0 y0 w%A_ScreenWidth% h%A_ScreenHeight%

  WinGetPos2(hwndTargetWindow, x, y, w, h)
  WinSet, Region, R15-15 W%w% H%h% %x%-%y%, ahk_id %hwndTargetOverlay%
}

ShowResizeOverlay(){
  Gui, 2:Color, %accentColor%
  Gui, 2:+AlwaysOnTop -Caption
  Gui, 2:+Owner1
  Gui, 2:+HwndhwndResizeOverlay
  Gui, 2:+LastFound
  WinSet, Transparent, 128

  Gui, 2:Show, x0 y0 w%A_ScreenWidth% h%A_ScreenHeight%

  WinSet, Region, R15-15 W0 H0 0-0, ahk_id %hwndResizeOverlay%
}

SetResizeOverlay(e1, e2){
  ElemsUnionXYWH(e1, e2, x, y, w, h)
  WinSet, Region, R15-15 W%w% H%h% %x%-%y%, ahk_id %hwndResizeOverlay%
}

ShowControlWindow(monitor){
  SysGet, m, MonitorWorkArea, %monitor%

  mW := mRight - mLeft
  mH := mBottom - mTop

  sH := 200
  sW := sH * mW / mH
  bW := sW / colSize
  bH := sH / rowSize

  num := monitor + 2  

  Loop, %rowSize%
  {
    Gui, %num%:add, Button, x10 w%bW% h%bH%,
    i := colSize - 1
    Loop, %i%
    {
      Gui, %num%:add, Button, x+0 yp+0 w%bW% h%bH%,
    }
    Gui, %num%:Margin, 10, 0
  }
  Gui, %num%:Margin,, 8

  Gui, %num%:+AlwaysOnTop -MaximizeBox -MinimizeBox +Owner2

  Gui, %num%:+LastFound
  Gui, %num%:Show, Hide

  hwndControlWindowList := Trim(hwndControlWindowList . " " . WinExist())

  GetClientSize(WinExist(), cW, cH)
  xc := (mLeft + mRight) / 2 - cW / 2
  yc := (mTop + mBottom) / 2 - cH / 2
  Gui, %num%:Show, x%xc% y%yc%, #%monitor%
}

; ========
; Helper
; ========

ElemTBLR(elem, ByRef top, ByRef bottom, ByRef left, ByRef right){
  ; exclude taskbar region
  ; work on only under and horizontal taskbar
  WinGetPos,, ty,,, ahk_class Shell_TrayWnd
  
  rowH := ty / rowSize
  colW := A_ScreenWidth / colSize

  posX := Mod((elem-1), colSize) + 1
  posY := ((elem-1) // colSize) + 1
  
  top := (posY-1) * rowH
  bottom := posY * rowH
  left := (posX-1) * colW
  right := posX * colW
}

ElemsUnionXYWH(e1, e2, ByRef x, ByRef y, ByRef w, ByRef h){
  ElemTBLR(e1, e1T, e1B, e1L, e1R)
  ElemTBLR(e2, e2T, e2B, e2L, e2R)

  t := Min(e1T, e2T)
  b := Max(e1B, e2B)
  l := Min(e1L, e2L)
  r := Max(e1R, e2R)

  x := l
  y := t
  h := b - t
  w := r - l
}

IsControlWindow(hwnd){
  Loop, Parse, hwndControlWindowList, " "
     if(hwnd == A_LoopField)
      Return True    
  
  Return False
}

MouseGetElem(ByRef monitor, ByRef elem){
  MouseGetPos,,, hwnd, control
  if(!IsControlWindow(hwnd))
    Return

  WinGetTitle, title, ahk_id %hwnd%
  monitor := Ltrim(title, "#")
  elem := Ltrim(control, "Button")
}

; ========
; Logic
; ========

Init(){
  hwndControlWindowList := ""
  hwndResizeOverlay := ""
  hwndTargetOverlay:= ""
  hwndTargetWindow := ""
  elemFrom := 0
  elemTo := 0
}

OverlaysExist(){
  if(hwndControlWindowList == "")
    Return false

  Loop, Parse, hwndControlWindowList, " "
    if(!WinExist("ahk_id " . A_LoopField))
      Return False    
  
  Return True
}

ResizeTargetWindow(){
  ElemsUnionXYWH(elemFrom, elemTo, x, y, w, h)
  WinMove2(hwndTargetWindow, x, y, w, h)
}

CloseOverlays(){
  Loop, Parse, hwndControlWindowList, " "
    WinClose, ahk_id %A_LoopField%
  WinClose, ahk_id %hwndControlWindow%
  WinClose, ahk_id %hwndResizeOverlay%
  WinClose, ahk_id %hwndTargetOverlay%
}

HotkeyHandler(){
  if(OverlaysExist())
  {
    CloseOverlays()
    Return
  }

  Init()
  WinGet, hwndTargetWindow, ID, A

  ShowTargetOverlay()
  ShowResizeOverlay()
  SysGet, monitorCount, MonitorCount
  Loop, %monitorCount%
    ShowControlWindow(A_Index)

  While OverlaysExist()
  {
    MouseGetElem(m, n)
    if(m && n){
      SetResizeOverlay(SOR(elemFrom, n), SOR(elemTo, n))
    }
  }
}

ClickHandler(){
  MouseGetElem(m, n)
  if(!(m && n))
    Return
     
  if(!elemFrom){
    elemFrom := n
  } else {
    elemTo := n
  
    CloseOverlays()
    ResizeTargetWindow()
  }
}

; ========
; Hotkey
; ========
F1::
  HotkeyHandler()
Return

~LButton::
  ClickHandler()
Return

~Esc::
  CloseOverlays()
Return

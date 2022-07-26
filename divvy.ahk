#SingleInstance, Force
#MaxThreadsPerHotkey, 2
SendMode Input
SetWorkingDir, %A_ScriptDir%
SetWinDelay, 0

#include divvy.config.ahk

global hotkey
global rowSize
global colSize
global accentColor
global dragToResize

global hwndControlWindowList := ""
global hwndResizeOverlay := ""
global hwndTargetOverlay:= ""
global hwndTargetWindow := ""
global gridFrom := 0
global gridTo := 0
global targetMonitor := 0

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

VirtualScreenXYWH(ByRef x, ByRef y, ByRef w, ByRef h){
  t := 0
  b := 0
  l := 0
  r := 0

  SysGet, monitorCount, MonitorCount
  Loop, %monitorCount%
  {
    SysGet, m, Monitor, %A_Index%
    t := Min(t, mTop)
    b := Max(b, mBottom)
    l := Min(l, mLeft)
    r := Max(r, mRight)
  }

  x := l
  y := t
  w := r - l
  h := b - t
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

GetMonitorIndex(hwnd){
  WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%
  
  SysGet, monitorCount, MonitorCount
  Loop, %monitorCount%
  {
    SysGet, m, MonitorWorkArea, %A_Index%
    if(mLeft <= wx && wx <= mRight && mTop <= wy && wy <= mBottom)
    Return %A_Index%
  }

  SysGet, primary, MonitorPrimary
  Return %primary%
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

  VirtualScreenXYWH(vsX, vsY, vsW, vsH)
  Gui, Show, x%vsX% y%vsY% w%vsW% h%vsH%
  
  WinGetPos2(hwndTargetWindow, x, y, w, h)
  rX := x - vsX
  rY := y - vsY
  WinSet, Region, R15-15 W%w% H%h% %rX%-%rY%, ahk_id %hwndTargetOverlay%
}

ShowResizeOverlay(){
  Gui, 2:Color, %accentColor%
  Gui, 2:+AlwaysOnTop -Caption
  Gui, 2:+Owner1
  Gui, 2:+HwndhwndResizeOverlay
  Gui, 2:+LastFound
  WinSet, Transparent, 128

  VirtualScreenXYWH(vsX, vsY, vsW, vsH)
  Gui, 2:Show, x%vsX% y%vsY% w%vsW% h%vsH%

  WinSet, Region, R15-15 W0 H0 0-0, ahk_id %hwndResizeOverlay%
}

SetResizeOverlay(monitor, e1, e2){
  GridsUnionXYWH(monitor, e1, e2, x, y, w, h)
  VirtualScreenXYWH(vsX, vsY, vsW, vsH)
  rX := x - vsX
  rY := y - vsY
  WinSet, Region, R15-15 W%w% H%h% %rX%-%rY%, ahk_id %hwndResizeOverlay%
}

ShowControlWindow(monitor){
  SysGet, m, MonitorWorkArea, %monitor%

  mW := mRight - mLeft
  mH := mBottom - mTop

  guiH := 200
  guiW := guiH * mW / mH
  bW := guiW / colSize
  bH := guiH / rowSize

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
; Logic
; ========

GridTBLR(monitor, grid, ByRef top, ByRef bottom, ByRef left, ByRef right){
  SysGet, m, MonitorWorkArea, %monitor%

  mW := mRight - mLeft
  mH := mBottom - mTop

  rowH := mH / rowSize
  colW := mW / colSize

  posX := Mod((grid-1), colSize) + 1
  posY := ((grid-1) // colSize) + 1
  
  top := mTop + (posY-1) * rowH
  bottom := mTop + posY * rowH
  left := mLeft + (posX-1) * colW
  right := mLeft + posX * colW
}

GridsUnionXYWH(monitor, e1, e2, ByRef x, ByRef y, ByRef w, ByRef h){
  GridTBLR(monitor, e1, e1T, e1B, e1L, e1R)
  GridTBLR(monitor, e2, e2T, e2B, e2L, e2R)

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

MouseGetGrid(ByRef monitor, ByRef grid){
  MouseGetPos,,, hwnd, control
  if(!IsControlWindow(hwnd))
    Return

  WinGetTitle, title, ahk_id %hwnd%
  monitor := Ltrim(title, "#")
  grid := Ltrim(control, "Button")
}

Init(){
  hwndControlWindowList := ""
  hwndResizeOverlay := ""
  hwndTargetOverlay:= ""
  hwndTargetWindow := ""
  gridFrom := 0
  gridTo := 0
  targetMonitor := 0
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
  GridsUnionXYWH(targetMonitor, gridFrom, gridTo, x, y, w, h)
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
    MouseGetGrid(m, n)
    if(m && n){
      SetResizeOverlay(m, SOR(gridFrom, n), SOR(gridTo, n))
    }
  }

  CloseOverlays()
}

ClickHandler(){
  MouseGetGrid(m, n)
  if(!(m && n))
    Return
     
  if(!gridFrom){
    gridFrom := n
  } else {
    gridTo := n
    targetMonitor := m

    CloseOverlays()
    ResizeTargetWindow()
  }
}

FitNearestGrid(){
  WinGetPos2(hwndTargetWindow, x, y, w, h)
  l := x
  r := x + w
  t := y
  b := y + h

  monitor := GetMonitorIndex(hwndTargetWindow)
  SysGet, m, MonitorWorkArea, %monitor%
  colW := (mRight - mLeft) / colSize
  rowH := (mBottom - mTop) / rowSize

  dL := colW
  dR := colW
  dT := rowH
  dB := rowH

  Loop, %colSize%
  {
    i := mLeft + colW * (A_Index - 1)
    
    if(Abs(l - i) < dL)
    {
      nL := i
      dL := Abs(l - i)
    }
    if(Abs(R - i) < dR)
    {
      nR := i
      dR := Abs(r - i)
    }
  }

  Loop, %rowSize%
  {
    i := mTop + rowH * (A_Index - 1)
    
    if(Abs(t - i) < dT)
    {
      nT := i
      dT := Abs(t - i)
    }
    if(Abs(b - i) < dB)
    {
      nB := i
      dB := Abs(b - i)
    }
  }
  
  nX := nL
  nY := nT
  nW := Max(nR - nL, colW)
  nH := Max(nB - nT, rowH)
  WinMove2(hwndTargetWindow, nX, nY, nW, nH)

  CloseOverlays()
}

; ========
; Hotkey
; ========

Hotkey, %hotkey%, Hotkey
Hotkey, %hotkeyFit%, HotkeyFit

Return

Hotkey:
  HotkeyHandler()
Return

#If OverlaysExist()
HotkeyFit:
  FitNearestGrid()
Return

#If
~LButton::
  ClickHandler()
Return

~Esc::
  CloseOverlays()
Return


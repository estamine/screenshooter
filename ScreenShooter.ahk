; <COMPILER: v1.0.48.5>
#Persistent

FormatHexNumber(_value, _digitNb)
{
	local hex, intFormat


	intFormat := A_FormatInteger

	SetFormat Integer, Hex

	hex := _value + (1 << 4 * _digitNb)
	StringRight hex, hex, _digitNb

	StringUpper hex, hex


	SetFormat Integer, %intFormat%

	Return hex
}

Bin2Hex(ByRef @hexString, ByRef @bin, _byteNb=0)
{
	local dataSize, dataAddress, granted, f


	dataSize := _byteNb < 1 ? VarSetCapacity(@bin) : _byteNb
	dataAddress := &@bin

	granted := VarSetCapacity(@hexString, dataSize * 5)
	if (granted < dataSize * 5)
	{

		ErrorLevel = Mem=%granted%
		Return -1
	}
	f := A_FormatInteger
	SetFormat Integer, H
	Loop %dataSize%
	{
		@hexString .= *(dataAddress++) + 256
	}
	StringReplace @hexString, @hexString, 0x1, , All
	StringUpper @hexString, @hexString
	SetFormat Integer, %f%

	Return dataSize
}

Hex2Bin(ByRef @bin, ByRef @hex, _byteNb=0)
{
	local l, data, granted, dataAddress

	If (_byteNb < 1 or _byteNb > dataSize)
	{

		l := StrLen(@hex)
		_byteNb := l // 2
		if (l = 0 or _byteNb * 2 != l)
		{

			ErrorLevel = Param
			Return -1
		}
	}

	granted := VarSetCapacity(@bin, _byteNb, 0)
	if (granted < _byteNb)
	{

		ErrorLevel = Mem=%granted%
		Return -1
	}
	data := RegExReplace(@hex, "..", "0x$0!")
	StringLeft data, data, _byteNb * 5
	dataAddress := &@bin

	Loop Parse, data, !
	{

		DllCall("RtlFillMemory"
				, "UInt", dataAddress++
				, "UInt", 1
				, "UChar", A_LoopField)
	}

	Return _byteNb
}
; #Include %A_ScriptDir%\BinaryEncodingDecoding.ahk

SetNextUInt(ByRef @struct, _value, _bReset=false)
{
	local addr
	static $offset

	If (_bReset)
	{
		$offset := 0
	}
	addr := &@struct + $offset
	$offset += 4
	DllCall("RtlFillMemory", "UInt", addr,     "UInt", 1, "UChar", (_value & 0x000000FF))
	DllCall("RtlFillMemory", "UInt", addr + 1, "UInt", 1, "UChar", (_value & 0x0000FF00) >> 8)
	DllCall("RtlFillMemory", "UInt", addr + 2, "UInt", 1, "UChar", (_value & 0x00FF0000) >> 16)
	DllCall("RtlFillMemory", "UInt", addr + 3, "UInt", 1, "UChar", (_value & 0xFF000000) >> 24)
}

GetNextUInt(ByRef @struct, _bReset=false)
{
	local addr
	static $offset

	If (_bReset)
	{
		$offset := 0
	}
	addr := &@struct + $offset
	$offset += 4

	Return *addr + (*(addr + 1) << 8) +  (*(addr + 2) << 16) + (*(addr + 3) << 24)
}

SetNextByte(ByRef @struct, _value, _bReset=false)
{
	local addr
	static $offset

	If (_bReset)
	{
		$offset := 0
	}
	addr := &@struct + $offset
	$offset++
	DllCall("RtlFillMemory", "UInt", addr, "UInt", 1, "UChar", _value)
}

GetNextByte(ByRef @struct, _bReset=false)
{
	local addr
	static $offset

	If (_bReset)
	{
		$offset := 0
	}
	addr := &@struct + $offset
	$offset++

	Return *addr
}






GetInteger(ByRef @source, _offset = 0, _size = 4, _bIsSigned = false)
{
	local result

	Loop %_size%
	{
		result += *(&@source + _offset + A_Index-1) << 8*(A_Index-1)
	}
	If (!_bIsSigned OR _size > 4 OR result < 0x80000000)
		Return result

	return -(0xFFFFFFFF - result + 1)
}




SetInteger(ByRef @dest, _integer, _offset = 0, _size = 4)
{
	Loop %_size%
	{
		DllCall("RtlFillMemory"
				, "UInt", &@dest + _offset + A_Index-1
				, "UInt", 1
				, "UChar", (_integer >> 8*(A_Index-1)) & 0xFF)
	}
}


GetUnicodeString(ByRef @unicodeString, _ansiString)
{
	local len

	len := StrLen(_ansiString)
	VarSetCapacity(@unicodeString, len * 2 + 1, 0)


	DllCall("MultiByteToWideChar"
			, "UInt", 0
			, "UInt", 0
			, "Str", _ansiString
			, "Int", len
			, "UInt", &@unicodeString
			, "Int", len)
}


GetAnsiStringFromUnicodePointer(_unicodeStringPt)
{
	local len, ansiString

	len := DllCall("lstrlenW", "UInt", _unicodeStringPt)
	VarSetCapacity(ansiString, len, 0)


	DllCall("WideCharToMultiByte"
			, "UInt", 0
			, "UInt", 0
			, "UInt", _unicodeStringPt
			, "Int", len
			, "Str", ansiString
			, "Int", len
			, "UInt", 0
			, "UInt", 0)

	Return ansiString
}

DumpDWORDs(ByRef @bin, _byteNb, _bExtended=false)
{
	Return DumpDWORDsByAddr(&@bin, _byteNb, _bExtended)
}

DumpDWORDsByAddr(_binAddr, _byteNb, _bExtended=false)
{
	local dataSize, dataAddress, granted, line, dump, hex, ascii
	local dumpWidth, offsetSize, resultSize

	offsetSize = 4
	dumpWidth = 32

	resultSize := _byteNb * 4
	If _bExtended
	{
		dumpWidth = 16
		resultSize += offsetSize + 8 + dumpWidth
	}
	granted := VarSetCapacity(dump, resultSize)
	if (granted < resultSize)
	{

		ErrorLevel = Mem=%granted%
		Return -1
	}
	If _bExtended
	{
		offset = 0
		line := FormatHexNumber(offset, offsetSize) ": "
	}
	Loop %_byteNb%
	{

		hex := FormatHexNumber(*_binAddr, 2)
		If _bExtended
		{

			If (*_binAddr >= 32)
			{
				ascii := ascii Chr(*_binAddr)
			}
			Else
			{
				ascii := ascii "."
			}
			offset++
		}
		line := line hex A_Space
		If (Mod(A_Index, dumpWidth) = 0)
		{

			If (_bExtended)
			{

				line := line " - " ascii
				ascii =
			}
			dump := dump line "`n"
			line =
			If (_bExtended && A_Index < _byteNb)
			{
				line := FormatHexNumber(offset, offsetSize) ": "
			}
		}
		Else If (Mod(A_Index, 4) = 0)
		{

			line := line "| "
		}
		_binAddr++
	}
	If (Mod(_byteNb, dumpWidth) != 0)
	{
		If (_bExtended)
		{
			line := line " - " ascii
		}
		dump := dump line "`n"
	}

	Return dump
}
; #Include DllCallStruct.ahk

Gdip_CropImage(pBitmap, x, y, w, h)
{
   pBitmap2 := Gdip_CreateBitmap(w, h), G2 := Gdip_GraphicsFromImage(pBitmap2)
   Gdip_DrawImage(G2, pBitmap, 0, 0, w, h, x, y, w, h)
   Gdip_DeleteGraphics(G2)
   return pBitmap2
}


#Include, Gdip_All.ahk
#SingleInstance
SetWinDelay, 0
Coordmode, ToolTip, Screen
Coordmode, Mouse, Screen
Menu, TRAY, add
Menu, TRAY, add, Show Save Directory, ShowDir
Menu, TRAY, add, Delete all images in Save Directory, DeleteAll

Menu, TRAY, add
Menu, TRAY, add, Take a Screenshot (Win + Y), TakeScreenshot
Menu, TRAY ,Tip , ScreenShooter (Win + Y)

return

ShowDir:
Run, %A_ScriptDir%
return

DeleteAll:
FileDelete, %A_ScriptDir%\*.png
return

#y::
KeyWait, y, L
GoTo TakeScreenshot
return

TakeScreenshot:
ToolTip, Please wait...

ToolTip
Sleep, 250

pToken := Gdip_Startup()

pBitmap := Gdip_BitmapFromScreen()
Gdip_SaveBitmapToFile(pBitmap, A_ScriptDir . "\screen.png")

Gdip_DisposeImage(pBitmap)
Gdip_Shutdown(pToken)

ToolTip, Please wait...
SysGet,swidth,78
SysGet,sheight,79
swidth:=swidth+10
sheight:=sheight+6

SysGet,xvirtual,76
SysGet,yvirtual,77
xvirtual:=xvirtual-10
yvirtual:=yvirtual-6
ToolTip, Please wait...

Gui, +AlwaysOnTop -caption -Border +ToolWindow +LastFound
Gui, Add, Picture, , %A_ScriptDir%\screen.png
Gui, Show, x%xvirtual% y%yvirtual% w%swidth% h%sheight%, scshwin

ToolTip, Please wait...
MouseGetPos, MXini, MYini
ToolTip, Alt+Drag to select area`nESC to cancel.
ControlGet, TTHWND, HWND,,,ahk_class tooltips_class32
IfWinNotExist, scshwin
    return
Gui, 2:+AlwaysOnTop -caption +Border +ToolWindow +LastFound
WinSet, TransColor, White
Gui, 2:Color, white
w:=0
h:=0
stillon = 1
While, (w==0 or h ==0)
{
If stillon = 0
   return
MouseGetPos, MX, MY
ToolTip, Drag to select area:`nx: %MX% y: %MY%`nESC to cancel.
While, (GetKeyState("LButton", "p"))
{
If stillon = 0
   return

   MouseGetPos, MXend, MYend
   Send {control up}
   w := abs(MX - MXend)
   h := abs(MY - MYend)
   If ( MX < MXend )
   X := MX
   Else
   X := MXend
   If ( MY < MYend )
   Y := MY
   Else
   Y := MYend
   Gui, 2:Show, x%X% y%Y% w%w% h%h%
   ToolTip, Selected area:`nini x: %x% ini y: %y% `ncur x: %MXend% cur y: %MYend% `nw: %w% h: %h%`nPress ESC to cancel.
   Sleep, 50

}
}
ToolTip
Sleep, 50
Gui, Destroy
Gui, 2:Destroy

pToken := Gdip_Startup()

pBitmap := Gdip_BitmapFromScreen()
pBitmap2 := Gdip_CropImage(pBitmap, X+1, Y+1, w-1, h-1)
Gdip_SetBitmapToClipboard(pBitmap2)

IniRead, DEFNAME, ScreenShooter.ini, Main, Filename
Gdip_SaveBitmapToFile(pBitmap2, "image.png")

Gdip_DisposeImage(pBitmap)
Gdip_DisposeImage(pBitmap2)
Gdip_Shutdown(pToken)

ArrayCount = 0




AGAIN:

Gui, 2:Destroy
Gui, Destroy

Gui, 3:+AlwaysOnTop
Gui, 3:Add, Text,, Image saved to Clipboard.`n`nEnter filename without extension.`nPress ESC to cancel.
Gui, 3:Add, Edit, w400 r1 vnewname,%DEFNAME%
Gui, 3:Add, Button, Default x10 y90 w60 h30, &OK
Gui, 3:Add, Button, x80 y90 w60 h30, &Edit
Gui, 3:Add, Button, x160 y90 w60 h30 , &Cancel
Gui, 3:Show, , Save screenshot
return

3ButtonEdit:
GuiControlGet, newname
Gui, 3:Destroy
if (newname=="")
{
newname=%A_now%
}

IfExist, %A_ScriptDir%\%newname%.png
MsgBox, 54, Image file already exists, Image file already exists: `n`n%A_ScriptDir%\%newname%.png
IfMsgBox TryAgain
    GoTo AGAIN
IfMsgBox Cancel
	return

FileMove, %A_ScriptDir%\image.png, %A_ScriptDir%\%newname%.png,1
Clipboard = %A_ScriptDir%\%newname%.png

FileDelete, ScreenShooter.ini



IniWrite, %newname%, ScreenShooter.ini, Main, Filename

run, mspaint.exe "%A_ScriptDir%\%newname%.png", ,Max


return

3ButtonOK:
GuiControlGet, newname
Gui, 3:Destroy
if (newname=="")
{
newname=%A_now%
}

IfExist, %A_ScriptDir%\%newname%.png
MsgBox, 54, Image file already exists, Image file already exists: `n`n%A_ScriptDir%\%newname%.png
IfMsgBox TryAgain
    GoTo AGAIN
IfMsgBox Cancel
	return
FileMove, %A_ScriptDir%\image.png, %A_ScriptDir%\%newname%.png,1
Clipboard = %A_ScriptDir%\%newname%.png





FileDelete, ScreenShooter.ini
IniWrite, %newname%, ScreenShooter.ini, Main, Filename

;Esc::
3ButtonCancel:
GuiClose:
GuiEscape:
2GuiClose:
2GuiEscape:
3GuiClose:
3GuiEscape:
h:=0
w:=0
Gui, Hide
Gui, 2:Hide
Gui, 3:Hide
Gui, Destroy
Gui, 2:Destroy
Gui, 3:Destroy
ToolTip
stillon = 0

return


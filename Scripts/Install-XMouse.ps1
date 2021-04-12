$signature = @"
[DllImport("user32.dll")]
public static extern bool SystemParametersInfo(int uAction, int uParam, ref 
int lpvParam, int flags );
"@

# https://superuser.com/questions/954021/how-do-you-enable-focus-follows-mouse-in-windows-10
# https://docs.microsoft.com/nb-no/windows/win32/api/winuser/nf-winuser-systemparametersinfoa?redirectedfrom=MSDN

$systemParamInfo = Add-Type -memberDefinition  $signature -Name SloppyFocusMouse -passThru

[Int32]$newVal = 1
$systemParamInfo::SystemParametersInfo(0x1001, 0, [REF]$newVal, 2)

# det er også noe magi knyttet til
# ((Get-ItemProperty 'HKCU:\Control Panel\Desktop' UserPreferencesMask).UserPreferencesMask |% { '{0:X2}' -f $_ }) -join ' '
# men jeg finner ikke noe dokumetasjon av UserPreferencesMask for windows-10, finnes bare for win2k

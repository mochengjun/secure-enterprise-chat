; 企业安全聊天应用 - Inno Setup 安装脚本
; 使用方法: 安装 Inno Setup 后，右键此文件选择 "Compile" 或使用命令行 iscc installer.iss

#define MyAppName "企业安全聊天"
#define MyAppNameEn "SecChat"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Your Company Name"
#define MyAppURL "https://your-company.com"
#define MyAppExeName "sec_chat.exe"
#define MyAppIcon "..\..\apps\flutter_app\windows\runner\resources\app_icon.ico"

[Setup]
; 应用程序信息
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; 安装目录
DefaultDirName={autopf}\{#MyAppNameEn}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; 输出设置
OutputDir=.\output
OutputBaseFilename=SecChat-Setup-{#MyAppVersion}
SetupIconFile={#MyAppIcon}
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

; 权限设置
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; 界面设置
WizardStyle=modern
WizardSizePercent=120

; 支持的架构
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; 其他设置
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; 主程序和DLL文件
Source: "..\..\apps\flutter_app\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\apps\flutter_app\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\apps\flutter_app\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Visual C++ 运行时 (如果需要)
; Source: "vcredist_x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// 检查是否需要安装 Visual C++ 运行时
function NeedsVCRedist: Boolean;
var
  Version: String;
begin
  Result := not RegQueryStringValue(HKLM, 
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 
    'Version', Version);
end;

// 安装前检查
function InitializeSetup(): Boolean;
begin
  Result := True;
  
  // 检查Windows版本 (需要Windows 10或更高)
  if not IsWin64 then
  begin
    MsgBox('此应用程序需要64位Windows系统。', mbError, MB_OK);
    Result := False;
  end;
end;

// 卸载前确认
function InitializeUninstall(): Boolean;
begin
  Result := MsgBox('确定要卸载 {#MyAppName} 吗？', mbConfirmation, MB_YESNO) = IDYES;
end;

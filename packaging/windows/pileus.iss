; Inno Setup script for the Pileus Windows desktop build.
;
; Build the app first:
;   flutter build windows --release -t lib/main_desktop.dart
; then compile this script from the repo root:
;   iscc packaging\windows\pileus.iss /DAppVersion=1.2.3
;
; Output: dist\pileus-<version>-windows-x64-setup.exe
; A portable ZIP of build\windows\x64\runner\Release is produced separately
; by the CI workflow (.forgejo/workflows/windows.yml), not here.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define AppName "Pileus"
#define AppPublisher "Pileus contributors"
#define AppExeName "pileus.exe"
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
; Stable, do not change — a new GUID means Windows treats it as a different
; app (no in-place upgrade over an existing install).
AppId={{7F3A9C64-2B18-4D5E-9A67-1C4E8F2B6A3D}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\dist
OutputBaseFilename=pileus-{#AppVersion}-windows-x64-setup
LicenseFile=..\..\LICENSE

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll";        DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\data\*";       DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

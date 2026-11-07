$ErrorActionPreference = 'Stop'

# ===== 工具链路径：按你的环境改这里，或用同名环境变量覆盖 =====
$JAVA   = if ($env:JAVA_HOME)  { "$env:JAVA_HOME\bin" } else { 'C:\Android\jdk21\jdk-21.0.12.1+1\bin' }
$BT     = if ($env:BUILD_TOOLS){ $env:BUILD_TOOLS }      else { 'D:\Tools\Enviroments\Android\SDK\build-tools\37.0.0' }
$AJAR   = if ($env:ANDROID_JAR){ $env:ANDROID_JAR }      else { 'D:\Tools\Enviroments\Android\SDK\platforms\android-36\android.jar' }
$PY     = if ($env:PYTHON)     { $env:PYTHON }           else { 'python' }
$M      = $PSScriptRoot

$API_VER = '102.0.0'
$API_JAR = "$M\deps\libxposed-api-$API_VER.classes.jar"
$AAR_URL = "https://repo1.maven.org/maven2/io/github/libxposed/api/$API_VER/api-$API_VER.aar"

Set-Location $M
Remove-Item -Recurse -Force "$M\out","$M\flat" -ErrorAction SilentlyContinue | Out-Null
New-Item -Force -ItemType Directory "$M\out\classes","$M\out\stub-classes","$M\flat","$M\deps" | Out-Null

# ---- 0. 确保 libxposed-api classes.jar 就绪（缺失则从 Maven Central 下载 .aar 提取）----
if (-not (Test-Path $API_JAR)) {
    Write-Host "== fetch libxposed-api $API_VER aar from Maven Central =="
    & $PY -c @"
import urllib.request,zipfile,io,sys
url = r'$AAR_URL'
data = urllib.request.urlopen(url).read()
cj = zipfile.ZipFile(io.BytesIO(data)).read('classes.jar')
open(r'$API_JAR','wb').write(cj)
print('extracted',len(cj),'->',r'$API_JAR')
"@
    if ($LASTEXITCODE) { throw 'fetch libxposed-api failed' }
} else {
    Write-Host "== libxposed-api jar already present =="
}

# ---- 1. 编译编译期 stub（androidx.annotation / libxposed.annotation），不进 APK ----
Write-Host '== javac stubs (compileOnly) =='
$stubSrcs = Get-ChildItem "$M\stubsrc" -Recurse -Filter *.java | ForEach-Object FullName
& "$JAVA\javac.exe" -source 17 -target 17 -nowarn -parameters `
    -cp $AJAR `
    -d "$M\out\stub-classes" `
    $stubSrcs
if ($LASTEXITCODE) { throw 'javac stubs failed' }

# ---- 2. 编译模块自身，classpath = android.jar + api classes + stub classes ----
Write-Host '== javac module =='
& "$JAVA\javac.exe" -source 17 -target 17 -nowarn -parameters `
    -cp "$AJAR;$API_JAR;$M\out\stub-classes" `
    -d "$M\out\classes" `
    "$M\src\io\github\dbboxlauncherunlock\ModuleMain.java"
if ($LASTEXITCODE) { throw 'javac module failed' }

# ---- 3. 打 jar / d8 ----
Write-Host '== jar =='
& "$JAVA\jar.exe" --create --file "$M\out\classes.jar" -C "$M\out\classes" .
if ($LASTEXITCODE) { throw 'jar failed' }

Write-Host '== d8 =='
& "$BT\d8.bat" --release --min-api 28 --lib $AJAR --output "$M\out" "$M\out\classes.jar"
if ($LASTEXITCODE) { throw 'd8 failed' }
if (-not (Test-Path "$M\out\classes.dex")) { throw 'no classes.dex' }

# ---- 4. 打包资源 ----
Write-Host '== aapt2 compile+link =='
& "$BT\aapt2.exe" compile --dir "$M\res" -o "$M\flat\res.zip"
if ($LASTEXITCODE) { throw 'aapt2 compile failed' }
& "$BT\aapt2.exe" link -o "$M\out\module-unsigned.apk" `
    --manifest "$M\AndroidManifest.xml" `
    -I $AJAR `
    --auto-add-overlay `
    "$M\flat\res.zip"
if ($LASTEXITCODE) { throw 'aapt2 link failed' }

# ---- 5. 塞 classes.dex + META-INF/xposed ----
Write-Host '== merge classes.dex + META-INF/xposed =='
& $PY -c "import zipfile,os; res=r'$M\resources'; z=zipfile.ZipFile(r'$M\out\module-unsigned.apk','a',zipfile.ZIP_DEFLATED); z.write(r'$M\out\classes.dex','classes.dex'); [z.write(os.path.join(root,f), os.path.relpath(os.path.join(root,f),res).replace(os.sep,'/')) for root,_,files in os.walk(res) for f in files]; z.close()"

# ---- 6. zipalign + sign ----
Write-Host '== zipalign =='
& "$BT\zipalign.exe" -f 4 "$M\out\module-unsigned.apk" "$M\out\module-aligned.apk"
if ($LASTEXITCODE) { throw 'zipalign failed' }

if (-not (Test-Path "$M\module.keystore")) {
    Write-Host '== gen keystore =='
    & "$JAVA\keytool.exe" -genkeypair -v -keystore "$M\module.keystore" `
        -alias dbboxlauncher -keyalg RSA -keysize 2048 -validity 10000 `
        -storepass android -keypass android `
        -dname "CN=DBBoxLauncherUnlock, OU=tools, O=dbtools" 2>$null
    if ($LASTEXITCODE) { throw 'keytool failed' }
}

Write-Host '== apksigner =='
& "$BT\apksigner.bat" sign --ks "$M\module.keystore" `
    --ks-pass pass:android --key-pass pass:android `
    --out "$M\out\dbboxlauncher-unlock.apk" `
    "$M\out\module-aligned.apk"
if ($LASTEXITCODE) { throw 'apksigner failed' }

Write-Host "`n== DONE -> $M\out\dbboxlauncher-unlock.apk =="
Get-Item "$M\out\dbboxlauncher-unlock.apk" | Format-Table Name,Length

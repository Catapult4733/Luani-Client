"""Build/sign an Android APK in an isolated user folder; never install or run it."""
from pathlib import Path
import hashlib,json,os,secrets,shutil,subprocess,tarfile,zipfile
import xml.etree.ElementTree as ET
root=Path.home()/'.local/share/luani-build/android-preview-2'
root.mkdir(parents=True,exist_ok=True)
source=root/'source'
source.mkdir(exist_ok=True)
with tarfile.open(root/'source.tar.gz') as t:t.extractall(source,filter='data')
project=source/'offline'
templates=Path.home()/'.local/share/godot/export_templates/4.7.1.stable'
android=project/'android/build'
if not android.exists():
    android.mkdir(parents=True)
    with zipfile.ZipFile(templates/'android_source.zip') as z:
        for entry in z.infolist():
            if entry.filename.startswith('src/instrumented/') or entry.filename.startswith('src/androidTestInstrumented/'):continue
            z.extract(entry,android)
(project/'android/.build_version').write_text('4.7.1.stable')
(android/'.build_version').write_text('4.7.1.stable')
(android/'gradlew').chmod(0o755)
config=android/'config.gradle'
text=config.read_text().replace('compileSdk         : 36','compileSdk         : 35').replace('targetSdk          : 36','targetSdk          : 35').replace("buildTools         : '36.1.0'","buildTools         : '35.0.0'")
config.write_text(text)
# Reuse prebuilt native libraries; do not install an NDK into the owner's SDK.
module=android/'build.gradle'
module.write_text(module.read_text().replace('    ndkVersion versions.ndkVersion\n',''))
properties=android/'gradle.properties'
properties.write_text(properties.read_text()+'\ndoNotStrip=true\norg.gradle.java.installations.auto-download=false\n')
java_source=source/'distribution/android/java'
shutil.copytree(java_source,android/'src/main/java',dirs_exist_ok=True)
rules=android/'proguard-rules.pro'
keep='\n-keep class org.luani.client.LuaniWebsitePlugin { *; }\n'
old_rules=rules.read_text() if rules.exists() else ''
if keep not in old_rules:rules.write_text(old_rules+keep)
# Godot replaces the release activity manifest. A separate alias survives the
# merge and routes cold/warm VIEW intents to the unchanged stock activity.
manifest=android/'src/main/AndroidManifest.xml'
ns='http://schemas.android.com/apk/res/android'; ET.register_namespace('android',ns);ET.register_namespace('tools','http://schemas.android.com/tools')
tree=ET.parse(manifest);m=tree.getroot();app=m.find('application');assert app is not None
app.set('{'+ns+'}usesCleartextTraffic','false')
plugin_name='org.godotengine.plugin.v2.LuaniWebsite'
for old in list(app.findall('meta-data')):
    if old.get('{'+ns+'}name')==plugin_name:app.remove(old)
ET.SubElement(app,'meta-data',{'{'+ns+'}name':plugin_name,'{'+ns+'}value':'org.luani.client.LuaniWebsitePlugin'})
a=app.find('activity');assert a is not None
a.set('{'+ns+'}exported','true')
alias_name='fyi.luani.client.preview.LuaniLaunch'
for old in list(app.findall('activity-alias')):
    if old.get('{'+ns+'}name')==alias_name:app.remove(old)
target_activity=a.get('{'+ns+'}name');assert target_activity
alias=ET.SubElement(app,'activity-alias',{'{'+ns+'}name':alias_name,'{'+ns+'}targetActivity':target_activity,'{'+ns+'}exported':'true'})
f=ET.SubElement(alias,'intent-filter')
for tag,value in [('action','android.intent.action.VIEW'),('category','android.intent.category.DEFAULT'),('category','android.intent.category.BROWSABLE')]:
    ET.SubElement(f,tag,{'{'+ns+'}name':value})
ET.SubElement(f,'data',{'{'+ns+'}scheme':'luani','{'+ns+'}host':'launch'})
tree.write(manifest,encoding='utf-8',xml_declaration=True)
preset=(source/'distribution/android/export_presets.cfg').read_text()
(project/'export_presets.cfg').write_text(preset)
settings=root/'config/godot'; settings.mkdir(parents=True,exist_ok=True)
jdk=root/'tools/jdk-17.0.21+9';sdk=Path.home()/'Android/Sdk'
(settings/'editor_settings-4.7.tres').write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/android/android_sdk_path='+json.dumps(str(sdk))+'\nexport/android/java_sdk_path='+json.dumps(str(jdk))+'\n')
data=root/'data/godot/export_templates';data.mkdir(parents=True,exist_ok=True)
if not (data/'4.7.1.stable').exists():(data/'4.7.1.stable').symlink_to(templates,target_is_directory=True)
env=os.environ.copy();env.update(JAVA_HOME=str(jdk),ANDROID_HOME=str(sdk),ANDROID_SDK_ROOT=str(sdk),PATH=str(jdk/'bin')+':'+env['PATH'],GRADLE_USER_HOME=str(root/'gradle'),XDG_CONFIG_HOME=str(root/'config'),XDG_DATA_HOME=str(root/'data'),XDG_CACHE_HOME=str(root/'cache'))
# No native compilation is needed: the official AAR includes each selected ABI.
env['GRADLE_OPTS']='-Xmx2048m -Dorg.gradle.workers.max=2'
policy_tests=root/'policy-tests';policy_tests.mkdir(exist_ok=True)
subprocess.run([str(jdk/'bin/javac'),'-d',str(policy_tests),str(java_source/'org/luani/client/WebsitePolicy.java'),str(source/'tools/java/WebsitePolicyTest.java')],check=True,env=env)
subprocess.run([str(jdk/'bin/java'),'-cp',str(policy_tests),'org.luani.client.WebsitePolicyTest'],check=True,env=env)
artifacts=root/'artifacts';artifacts.mkdir(exist_ok=True)
unsigned=artifacts/'luani-android-unsigned.apk'
log=root/'android-export.log'
command=[str(Path.home()/'Desktop/Godot_v4.7.1-stable_linux.x86_64'),'--headless','--path',str(project),'--editor','--export-release','Android Preview',str(unsigned)]
print('Exporting Android with existing Godot4.7.1, SDK35 and task-local verified JDK17; no gameplay.',flush=True)
with log.open('w') as output:
    result=subprocess.run(command,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=900)
if result.returncode or not unsigned.exists() or 'SCRIPT ERROR:' in log.read_text(errors='replace'):
    print('\n'.join(log.read_text(errors='replace').splitlines()[-100:]),flush=True)
    raise SystemExit('Android export failed; complete log retained in build folder')
private=Path.home()/'.local/share/luani-build/private';private.mkdir(mode=0o700,exist_ok=True);private.chmod(0o700)
password=private/'android-preview.password';key=private/'android-preview.p12'
if not password.exists():password.write_text(secrets.token_urlsafe(48));password.chmod(0o600)
if not key.exists():
    keyenv=env.copy();keyenv['LUANI_ANDROID_SIGNING_PASSWORD']=password.read_text()
    r=subprocess.run([str(jdk/'bin/keytool'),'-genkeypair','-keystore',str(key),'-storetype','PKCS12','-storepass:env','LUANI_ANDROID_SIGNING_PASSWORD','-keypass:env','LUANI_ANDROID_SIGNING_PASSWORD','-alias','luani-preview','-keyalg','RSA','-keysize','3072','-validity','3650','-dname','CN=Luani Android Preview,O=Luani'],env=keyenv,capture_output=True,text=True)
    assert r.returncode==0,'Signing-key generation failed (private output suppressed)'
    key.chmod(0o600)
tools=sdk/'build-tools/35.0.0'
aligned=artifacts/'luani-android-aligned.apk'
subprocess.run([str(tools/'zipalign'),'-P','16','-f','4',str(unsigned),str(aligned)],check=True,env=env)
apk=artifacts/'luani-client-0.5.0-android.2.apk'
subprocess.run([str(tools/'apksigner'),'sign','--ks',str(key),'--ks-key-alias','luani-preview','--ks-pass','file:'+str(password),'--out',str(apk),str(aligned)],check=True,env=env)
verified=subprocess.check_output([str(tools/'apksigner'),'verify','--verbose','--print-certs',str(apk)],env=env,text=True)
badging=subprocess.check_output([str(tools/'aapt'),'dump','badging',str(apk)],env=env,text=True)
manifest_xml=subprocess.check_output([str(tools/'aapt'),'dump','xmltree',str(apk),'AndroidManifest.xml'],env=env,text=True)
assert 'android:scheme' in manifest_xml and '"luani"' in manifest_xml and '"launch"' in manifest_xml, 'APK lost the Luani deep-link filter'
assert "package: name='fyi.luani.client.preview'" in badging and "versionCode='50002'" in badging
assert 'org.godotengine.plugin.v2.LuaniWebsite' in manifest_xml and 'org.luani.client.LuaniWebsitePlugin' in manifest_xml
assert '3b2d0f7a69043c6d61a4264f3258ae3fbbb2625678c841c03a42066ffa7b64a2' in verified,'Update signing certificate changed'
assert 'android.permission.INTERNET' in badging and 'application-debuggable' not in badging
with zipfile.ZipFile(apk) as z:
    assert any(n.endswith('Godot-LICENSE.txt') for n in z.namelist()), 'Godot license missing'
    assert any(n.endswith('Godot-COPYRIGHT.txt') for n in z.namelist()), 'Third-party notices missing'
    assert any(n.endswith('OFL.txt') for n in z.namelist()), 'Font license missing'
    assert not any('keystore' in n.lower() or 'export_credentials' in n.lower() or n.endswith('.p12') for n in z.namelist())
    abis=sorted({n.split('/')[1] for n in z.namelist() if n.startswith('lib/') and n.endswith('.so')})
report={'source_archive_sha256':hashlib.sha256((root/'source.tar.gz').read_bytes()).hexdigest(),'apk':str(apk),'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'bytes':apk.stat().st_size,'abis':abis,'version':'0.5.0-android.2','version_code':50002,'min_sdk':24,'target_sdk':35,'godot':'4.7.1.stable','signature':verified,'manifest_badging':badging,'gameplay_executed':False,'installed_on_device':False}
(artifacts/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2),flush=True)

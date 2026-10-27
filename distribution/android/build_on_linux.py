"""Build/sign an Android APK in an isolated user folder; never install or run it."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,tarfile,zipfile
import xml.etree.ElementTree as ET
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--build-root',type=Path,default=Path.home()/'.local/share/luani-build/android-preview-3')
parser.add_argument('--render-profile',action='store_true',help='Build an isolated, non-shipping offline render QA APK')
args=parser.parse_args()
root=args.build_root.resolve()
if args.render_profile:assert root.name.endswith(('-baseline','-profile')),'QA builds require a separate task root'
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
(project/'android/.gdignore').write_text('')
(project/'android/.build_version').write_text('4.7.1.stable')
(android/'.build_version').write_text('4.7.1.stable')
for stale in android.rglob('*.import'):stale.unlink()
shutil.rmtree(project/'.godot',ignore_errors=True)
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
if not args.render_profile:
    alias=ET.SubElement(app,'activity-alias',{'{'+ns+'}name':alias_name,'{'+ns+'}targetActivity':target_activity,'{'+ns+'}exported':'true'})
    f=ET.SubElement(alias,'intent-filter')
    for tag,value in [('action','android.intent.action.VIEW'),('category','android.intent.category.DEFAULT'),('category','android.intent.category.BROWSABLE')]:
        ET.SubElement(f,tag,{'{'+ns+'}name':value})
    ET.SubElement(f,'data',{'{'+ns+'}scheme':'luani','{'+ns+'}host':'launch'})
tree.write(manifest,encoding='utf-8',xml_declaration=True)
preset=(source/'distribution/android/export_presets.cfg').read_text()
if args.render_profile:
    profile=root/'render-profile.gd';assert profile.is_file(),'Explicit non-shipping QA fixture required'
    (project/'qa_render_profile.gd').write_bytes(profile.read_bytes())
    (project/'qa_render_profile.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://qa_render_profile.gd" id="1"]\n[node name="RenderQA" type="Node"]\nscript=ExtResource("1")\n')
    config_file=project/'project.godot';text=config_file.read_text();assert text.count('run/main_scene="res://main.tscn"')==1
    config_file.write_text(text.replace('run/main_scene="res://main.tscn"','run/main_scene="res://qa_render_profile.tscn"'))
    preset=preset.replace('package/unique_name="fyi.luani.client.preview"','package/unique_name="fyi.luani.client.preview.renderqa"').replace('package/name="Luani Client"','package/name="Luani Render QA"')
    preset=preset.replace('architectures/armeabi-v7a=true','architectures/armeabi-v7a=false').replace('architectures/arm64-v8a=true','architectures/arm64-v8a=false')
version_match=re.search(r'^version/name="([^"]+)"$',preset,re.M)
code_match=re.search(r'^version/code=(\d+)$',preset,re.M)
package_match=re.search(r'^package/unique_name="([^"]+)"$',preset,re.M)
assert version_match is not None and code_match is not None and package_match is not None
version=version_match.group(1)
version_code=int(code_match.group(1))
package_name=package_match.group(1)
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
private=Path.home()/'.local/share/luani-build/private'
password=private/'android-preview.password';key=private/'android-preview.p12'
assert key.is_file() and password.is_file(),'Original update-signing material is required; do not generate a replacement'
tools=sdk/'build-tools/35.0.0'
aligned=artifacts/'luani-android-aligned.apk'
subprocess.run([str(tools/'zipalign'),'-P','16','-f','4',str(unsigned),str(aligned)],check=True,env=env)
apk=artifacts/('luani-client-'+version+('-renderqa' if args.render_profile else '')+'.apk')
subprocess.run([str(tools/'apksigner'),'sign','--ks',str(key),'--ks-key-alias','luani-preview','--ks-pass','file:'+str(password),'--out',str(apk),str(aligned)],check=True,env=env)
verified=subprocess.check_output([str(tools/'apksigner'),'verify','--verbose','--print-certs',str(apk)],env=env,text=True)
badging=subprocess.check_output([str(tools/'aapt'),'dump','badging',str(apk)],env=env,text=True)
manifest_xml=subprocess.check_output([str(tools/'aapt'),'dump','xmltree',str(apk),'AndroidManifest.xml'],env=env,text=True)
if not args.render_profile:assert 'android:scheme' in manifest_xml and '"luani"' in manifest_xml and '"launch"' in manifest_xml, 'APK lost the Luani deep-link filter'
assert "package: name='"+package_name+"'" in badging and "versionCode='"+str(version_code)+"'" in badging
assert 'org.godotengine.plugin.v2.LuaniWebsite' in manifest_xml and 'org.luani.client.LuaniWebsitePlugin' in manifest_xml
assert '3b2d0f7a69043c6d61a4264f3258ae3fbbb2625678c841c03a42066ffa7b64a2' in verified,'Update signing certificate changed'
assert 'android.permission.INTERNET' in badging and 'application-debuggable' not in badging
with zipfile.ZipFile(templates/'android_source.zip') as z:
    stock_icons={n:hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if n.startswith('res/') and n.endswith('.webp')}
branded_hashes=set()
for rel in ('mipmap-xxxhdpi-v4/icon.webp','mipmap-xxxhdpi-v4/icon_foreground.webp','mipmap-xxxhdpi-v4/icon_background.webp','mipmap-xxxhdpi-v4/icon_monochrome.webp','drawable/splash_icon.webp'):
    icon_file=android/'res'/rel;assert icon_file.is_file(),'Missing exported Luani branding resource: '+rel
    digest=hashlib.sha256(icon_file.read_bytes()).hexdigest();assert digest!=stock_icons.get('res/'+rel),'Stock Godot branding remained in '+rel
    branded_hashes.add(digest)
with zipfile.ZipFile(apk) as z:
    assert any(n.endswith('Godot-LICENSE.txt') for n in z.namelist()), 'Godot license missing'
    assert any(n.endswith('Godot-COPYRIGHT.txt') for n in z.namelist()), 'Third-party notices missing'
    assert any(n.endswith('OFL.txt') for n in z.namelist()), 'Font license missing'
    assert not any('keystore' in n.lower() or 'export_credentials' in n.lower() or n.endswith('.p12') for n in z.namelist())
    apk_webp_hashes={hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if n.startswith('res/') and n.endswith('.webp')}
    assert branded_hashes.issubset(apk_webp_hashes),'Packaged APK is missing exported Luani icon/splash resources'
    abis=sorted({n.split('/')[1] for n in z.namelist() if n.startswith('lib/') and n.endswith('.so')})
report={'source_archive_sha256':hashlib.sha256((root/'source.tar.gz').read_bytes()).hexdigest(),'apk':str(apk),'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'bytes':apk.stat().st_size,'abis':abis,'version':version,'version_code':version_code,'package':package_name,'nonshipping_render_qa':args.render_profile,'min_sdk':24,'target_sdk':35,'godot':'4.7.1.stable','signature':verified,'manifest_badging':badging,'gameplay_executed':False,'installed_on_device':False}
(artifacts/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2),flush=True)

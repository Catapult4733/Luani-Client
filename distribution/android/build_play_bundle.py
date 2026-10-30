"""Export and audit a real Google Play AAB with the existing verified upload key.

Run only on the authorised build machine, with an exclusive task root and pinned
source archive. Never submits to Play, generates a key, or changes the APK channel.
"""
from pathlib import Path
import argparse,base64,hashlib,json,os,re,shutil,subprocess,sys,tarfile,zipfile
import xml.etree.ElementTree as ET

ANDROID='http://schemas.android.com/apk/res/android'
UPLOAD='62:99:94:9F:F5:57:1E:83:5A:1F:92:E5:A3:51:AE:02:45:69:5D:85:43:09:FD:E5:F3:D4:2D:A1:11:45:3D:BB'
BUNDLETOOL_SHA='a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29'

def sha(path):
    digest=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1048576),b''):digest.update(chunk)
    return digest.hexdigest()

def certificate(pem):
    blocks=re.findall(r'-----BEGIN CERTIFICATE-----\s*([A-Za-z0-9+/=\s]+?)\s*-----END CERTIFICATE-----',pem)
    assert blocks,'No public certificate in signer output'
    digest=hashlib.sha256(base64.b64decode(blocks[0])).hexdigest()
    return ':'.join(digest[i:i+2].upper() for i in range(0,len(digest),2))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-root',type=Path,required=True)
    parser.add_argument('--source-sha256',required=True)
    parser.add_argument('--source-commit',required=True)
    args=parser.parse_args();root=args.build_root.resolve()
    assert root.parent==Path.home()/'.local/share/luani-build' and root.name.startswith('play-closed-')
    assert re.fullmatch('[a-f0-9]{64}',args.source_sha256) and re.fullmatch('[a-f0-9]{40}',args.source_commit)
    archive=root/'source.tar.gz';assert sha(archive)==args.source_sha256
    source=root/'source';assert not source.exists(),'Do not mix source snapshots in a reused build root'
    with tarfile.open(archive) as bundle:
        assert bundle.pax_headers.get('comment')==args.source_commit,'Archive is not from the pinned git commit'
        bundle.extractall(source,filter='data')
    sys.path.insert(0,str(source/'distribution/android'))
    from play_bundle_audit import audit_native_bundle
    project=source/'offline';android=project/'android/build'
    templates=Path.home()/'.local/share/godot/export_templates/4.7.1.stable/android_source.zip'
    android.mkdir(parents=True)
    with zipfile.ZipFile(templates) as template:
        for entry in template.infolist():
            if entry.filename.startswith(('src/instrumented/','src/androidTestInstrumented/')):continue
            assert not Path(entry.filename).is_absolute() and '..' not in Path(entry.filename).parts
            template.extract(entry,android)
        stock={n:sha256_bytes(template.read(n)) for n in template.namelist() if n.startswith('res/') and n.endswith('.webp')}
    (project/'android/.gdignore').write_text('')
    for path in (project/'android/.build_version',android/'.build_version'):path.write_text('4.7.1.stable')
    (android/'gradlew').chmod(0o755)
    config=(android/'config.gradle').read_text()
    assert re.search(r'compileSdk\s*:\s*36',config) and re.search(r'targetSdk\s*:\s*36',config),'Never silently downgrade Play target SDK'
    assert "buildTools         : '36.1.0'" in config
    module=android/'build.gradle';module.write_text(module.read_text().replace('    ndkVersion versions.ndkVersion\n',''))
    properties=android/'gradle.properties';properties.write_text(properties.read_text()+'\ndoNotStrip=true\norg.gradle.java.installations.auto-download=false\n')
    java_source=source/'distribution/android/java';shutil.copytree(java_source,android/'src/main/java',dirs_exist_ok=True)
    rules=android/'proguard-rules.pro';rules.write_text((rules.read_text() if rules.exists() else '')+'\n-keep class org.luani.client.LuaniWebsitePlugin { *; }\n')
    preset=(source/'distribution/android/export_play.cfg').read_text();(project/'export_presets.cfg').write_text(preset)
    vm=re.search(r'^version/name="([^"]+)"$',preset,re.M);cm=re.search(r'^version/code=(\d+)$',preset,re.M);version=vm.group(1) if vm else "0.5.0-play.2";version_code=int(cm.group(1)) if cm else 50006
    assert 'package/unique_name="com.luani.client"' in preset and 'gradle_build/target_sdk="36"' in preset and 'gradle_build/export_format=1' in preset
    ET.register_namespace('android',ANDROID);ET.register_namespace('tools','http://schemas.android.com/tools')
    manifest=android/'src/main/AndroidManifest.xml';tree=ET.parse(manifest);app=tree.getroot().find('application');assert app is not None
    app.set('{'+ANDROID+'}usesCleartextTraffic','false')
    ET.SubElement(app,'meta-data',{'{'+ANDROID+'}name':'org.godotengine.plugin.v2.LuaniWebsite','{'+ANDROID+'}value':'org.luani.client.LuaniWebsitePlugin'})
    activity=app.find('activity');assert activity is not None
    target=activity.get('{'+ANDROID+'}name');assert target
    activity.set('{'+ANDROID+'}exported','true')
    alias=ET.SubElement(app,'activity-alias',{'{'+ANDROID+'}name':'com.luani.client.LuaniLaunch','{'+ANDROID+'}targetActivity':target,'{'+ANDROID+'}exported':'true'})
    f=ET.SubElement(alias,'intent-filter')
    for tag,value in [('action','android.intent.action.VIEW'),('category','android.intent.category.DEFAULT'),('category','android.intent.category.BROWSABLE')]:ET.SubElement(f,tag,{'{'+ANDROID+'}name':value})
    ET.SubElement(f,'data',{'{'+ANDROID+'}scheme':'luani','{'+ANDROID+'}host':'launch'})
    tree.write(manifest,encoding='utf-8',xml_declaration=True)
    jdk=root/'tools/jdk-17.0.21+9';sdk=root/'sdk';bundletool=root/'bundletool-all-1.18.3.jar'
    assert sha(bundletool)==BUNDLETOOL_SHA and (sdk/'platforms/android-36/android.jar').is_file()
    key=root/'private/legacy-upload.keystore';password=root/'private/legacy-upload.password'
    assert key.is_file() and password.is_file()
    env=os.environ.copy();env.update(JAVA_HOME=str(jdk),PATH=str(jdk/'bin')+':'+env['PATH'],ANDROID_HOME=str(sdk),ANDROID_SDK_ROOT=str(sdk),ANDROID_USER_HOME=str(root/'android-user'),GRADLE_USER_HOME=str(root/'gradle'),XDG_CONFIG_HOME=str(root/'config'),XDG_DATA_HOME=str(root/'data'),XDG_CACHE_HOME=str(root/'cache'),GRADLE_OPTS='-Xmx2048m -Dorg.gradle.workers.max=2')
    cert=subprocess.run([str(jdk/'bin/keytool'),'-exportcert','-rfc','-keystore',str(key),'-alias','luani','-storepass:file',str(password)],env=env,stdin=subprocess.DEVNULL,capture_output=True,text=True)
    assert cert.returncode==0 and certificate(cert.stdout)==UPLOAD,'Upload certificate verification failed; private diagnostics suppressed'
    settings=root/'config/godot';settings.mkdir(parents=True,exist_ok=True)
    (settings/'editor_settings-4.7.tres').write_text('[gd_resource type="EditorSettings" format=3]\n[resource]\nexport/android/android_sdk_path='+json.dumps(str(sdk))+'\nexport/android/java_sdk_path='+json.dumps(str(jdk))+'\n')
    data=root/'data/godot/export_templates';data.mkdir(parents=True,exist_ok=True);(data/'4.7.1.stable').symlink_to(templates.parent,target_is_directory=True)
    policy=root/'policy-tests';policy.mkdir();subprocess.run([str(jdk/'bin/javac'),'-d',str(policy),str(java_source/'org/luani/client/WebsitePolicy.java'),str(source/'tools/java/WebsitePolicyTest.java'),str(source/'tools/java/SupportPolicyTest.java')],env=env,check=True)
    subprocess.run([str(jdk/'bin/java'),'-cp',str(policy),'org.luani.client.WebsitePolicyTest'],env=env,check=True)
    subprocess.run([str(jdk/'bin/java'),'-cp',str(policy),'org.luani.client.SupportPolicyTest'],env=env,check=True)
    out=root/'artifacts';out.mkdir();unsigned=out/'luani-play-unsigned.aab';aab=out/('luani-client-'+version+'-'+str(version_code)+'.aab')
    log=root/'play-export.log';print('Exporting actual AAB with SDK36 and the original verified Play upload certificate.',flush=True)
    with log.open('w') as stream:
        result=subprocess.run([str(Path.home()/'Desktop/Godot_v4.7.1-stable_linux.x86_64'),'--headless','--path',str(project),'--editor','--export-release','Google Play Closed Test',str(unsigned)],env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=900)
    if result.returncode or not unsigned.is_file() or 'SCRIPT ERROR:' in log.read_text(errors='replace'):
        print('\n'.join(log.read_text(errors='replace').splitlines()[-90:]));raise SystemExit('Play AAB export failed; no replacement key or provider submission performed')
    subprocess.run([str(jdk/'bin/jarsigner'),'-keystore',str(key),'-storepass:file',str(password),'-digestalg','SHA-256','-signedjar',str(aab),str(unsigned),'luani'],env=env,stdin=subprocess.DEVNULL,check=True,capture_output=True)
    jarcheck=subprocess.run([str(jdk/'bin/jarsigner'),'-verify','-verbose','-certs',str(aab)],env=env,capture_output=True,text=True);(out/'jarsigner-verification.txt').write_text(jarcheck.stdout+jarcheck.stderr)
    assert jarcheck.returncode==0 and 'jar verified.' in jarcheck.stdout and 'jar is unsigned' not in jarcheck.stdout
    signed_cert=subprocess.check_output([str(jdk/'bin/keytool'),'-printcert','-rfc','-jarfile',str(aab)],env=env,text=True)
    assert certificate(signed_cert)==UPLOAD,'AAB signed by an unexpected certificate'
    command=[str(jdk/'bin/java'),'-jar',str(bundletool)]
    def bt(*parts):return subprocess.check_output(command+list(parts),env=env,text=True,stderr=subprocess.STDOUT,timeout=240)
    valid=bt('validate','--bundle='+str(aab));(out/'bundletool-validation.txt').write_text(valid)
    xml=bt('dump','manifest','--bundle='+str(aab));(out/'AndroidManifest.xml').write_text(xml)
    parsed=ET.fromstring(xml);assert parsed.get('package')=='com.luani.client' and parsed.get('{'+ANDROID+'}versionCode')==str(version_code)
    uses=parsed.find('uses-sdk');assert uses is not None and uses.get('{'+ANDROID+'}targetSdkVersion')=='36'
    permissions={p.get('{'+ANDROID+'}name','') for p in parsed.findall('uses-permission')};assert permissions=={'android.permission.INTERNET'}
    assert 'org.luani.client.LuaniWebsitePlugin' in xml and 'com.luani.client.LuaniLaunch' in xml and 'android:scheme="luani"' in xml
    cfg=bt('dump','config','--bundle='+str(aab));(out/'BundleConfig.json').write_text(cfg)
    libs=audit_native_bundle(aab);assert all(x['compatible_16kb'] for x in libs),'Native ELF/RELRO16KB audit failed'
    expected_abis={'armeabi-v7a','arm64-v8a','x86_64'};assert {x['abi'] for x in libs}==expected_abis
    branded=[]
    for rel in ('mipmap-xxxhdpi-v4/icon.webp','mipmap-xxxhdpi-v4/icon_foreground.webp','mipmap-xxxhdpi-v4/icon_background.webp','mipmap-xxxhdpi-v4/icon_monochrome.webp','drawable/splash_icon.webp'):
        digest=sha(android/'res'/rel);assert digest!=stock.get('res/'+rel);branded.append(digest)
    with zipfile.ZipFile(aab) as z:
        names=z.namelist()
        for notice in ('Godot-LICENSE.txt','Godot-COPYRIGHT.txt','OFL.txt'):assert any(n.endswith(notice) for n in names)
        images={sha256_bytes(z.read(n)) for n in names if n.startswith('base/res/') and n.endswith('.webp')};assert set(branded).issubset(images)
    apks=out/'generated-universal.apks';print('AAB signed; checking actual bundletool-generated APK and native packaging.',flush=True)
    generated=bt('build-apks','--bundle='+str(aab),'--output='+str(apks),'--mode=universal','--ks='+str(key),'--ks-key-alias=luani','--ks-pass=file:'+str(password))
    (out/'bundletool-build-apks.txt').write_text(generated)
    with zipfile.ZipFile(apks) as z:
        apk=out/'universal.apk'
        with z.open('universal.apk') as inp,apk.open('wb') as dest:shutil.copyfileobj(inp,dest)
    tools=sdk/'build-tools/36.1.0'
    verified=subprocess.check_output([str(tools/'apksigner'),'verify','--verbose','--print-certs',str(apk)],env=env,text=True);assert UPLOAD.replace(':','').lower() in verified
    badging=subprocess.check_output([str(tools/'aapt'),'dump','badging',str(apk)],env=env,text=True)
    assert "package: name='com.luani.client'" in badging and f"versionCode='{version_code}'" in badging and "targetSdkVersion:'36'" in badging and 'application-debuggable' not in badging
    with zipfile.ZipFile(apk) as z:
        native=[n for n in z.infolist() if n.filename.startswith('lib/') and n.filename.endswith('.so')];compressed=all(n.compress_type!=zipfile.ZIP_STORED for n in native)
    assert 'PAGE_ALIGNMENT_16K' in cfg or compressed,'Generated native packaging is neither16KB-aligned nor compressed'
    aligned=subprocess.run([str(tools/'zipalign'),'-c','-P','16','-v','4',str(apk)],env=env,capture_output=True,text=True);assert aligned.returncode==0
    assert sha(archive)==args.source_sha256,'Source archive changed during build'
    report={'schema':1,'source_commit':args.source_commit,'source_archive_sha256':args.source_sha256,'aab':str(aab),'aab_sha256':sha(aab),'aab_bytes':aab.stat().st_size,'package':'com.luani.client','version':version,'version_code':version_code,'target_sdk':36,'min_sdk':24,'abis':sorted(expected_abis),'upload_certificate_sha256':UPLOAD,'provided_play_upload_certificate_match':True,'new_key_generated':False,'bundletool_version':'1.18.3','bundletool_sha256':BUNDLETOOL_SHA,'aab_signature_verified':True,'bundletool_validate_passed':True,'native_elf_checks':libs,'bundle_requests_16kb_alignment':'PAGE_ALIGNMENT_16K' in cfg,'generated_apk_all_native_libraries_compressed':compressed,'generated_apk_zipalign_16k_passed':True,'generated_apk':str(apk),'generated_apk_sha256':sha(apk),'permissions':sorted(permissions),'luani_branding_verified':True,'required_notices_retained':True,'google_play_submitted':False,'google_play_approved':False,'runtime_exercised':False,'policy_declarations_completed':False}
    (out/'play-build-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))

def sha256_bytes(data):return hashlib.sha256(data).hexdigest()
if __name__=='__main__':main()

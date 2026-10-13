#!/usr/bin/env python3
"""Installed GHOSTNET release updates; never installs SDKs or writes package-owned files."""
import argparse, hashlib, json, os, pathlib, platform, plistlib, re, shutil, stat, subprocess, sys, tempfile, time, uuid, zipfile
REPO='https://github.com/galvatrone/CPP-Builder-Gostnet-'
ALLOWED={'ban.sh','ban-ru.sh','ghostnet','ghostnet-ru','install.sh','ghostnet-update.py','GHOSTNET-Install.sh','GHOSTNET-Install.command','GHOSTNET-Install.cmd','ban.cmd','ban-ru.cmd','ban.command','ban-ru.command','README.md','README.ru.md','LICENSE','ghostnet.bash','ghostnet.zsh','ghostnet.ps1','ghostnet.1'}
REQUIRED={'ban.sh','ban-ru.sh','ghostnet','ghostnet-ru','install.sh','ghostnet-update.py'}

def read_json(path):
    if path.is_symlink(): raise ValueError('Metadata must not be a symlink: '+str(path))
    return json.loads(path.read_text(encoding='utf-8-sig')) if path.exists() else {}

def atomic(path,data):
    if path.is_symlink(): raise ValueError('Output must not be a symlink: '+str(path))
    path.parent.mkdir(parents=True,exist_ok=True)
    fd,name=tempfile.mkstemp(prefix='.ghostnet-',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as f:f.write(data);f.flush();os.fsync(f.fileno())
        os.replace(name,path)
    finally:
        if os.path.exists(name):os.unlink(name)

def write_json(path,data):atomic(path,(json.dumps(data,ensure_ascii=False)+'\n').encode())
def version_tuple(value):
    if not re.fullmatch(r'v\d+\.\d+\.\d+',value): raise ValueError('Invalid stable release tag')
    return tuple(map(int,value[1:].split('.')))

def latest():
    r=subprocess.run(['curl','--fail','--location','--silent','--show-error','--proto','=https','--tlsv1.2','--connect-timeout','3','--max-time','6','--head','--output',os.devnull,'--write-out','%{url_effective}',REPO+'/releases/latest'],capture_output=True,text=True,timeout=8)
    if r.returncode:raise RuntimeError('Cannot check GitHub releases: '+r.stderr.strip())
    url=r.stdout.strip();prefix=REPO+'/releases/tag/'
    if not url.startswith(prefix):raise ValueError('Unexpected release redirect')
    tag=url[len(prefix):];version_tuple(tag);return tag

def download(url,path):
    subprocess.run(['curl','--fail','--location','--silent','--show-error','--proto','=https','--tlsv1.2','--connect-timeout','5','--max-time','90',url,'--output',str(path)],check=True,timeout=95)
    if path.stat().st_size>16*1024*1024:raise ValueError('Release asset too large')

def context(root):
    windows=(root/'installation.json').is_file()
    store=root if windows else root/'share/ghostnet'
    if store.is_symlink():raise ValueError('Install directory must not be a symlink')
    metadata=store/('installation.json' if windows else 'active.json')
    state=read_json(metadata);payload=pathlib.Path(state.get('Payload',str(store)))
    if state and (not payload.is_absolute() or os.path.normcase(os.path.commonpath([payload.resolve(),store.resolve()]))!=os.path.normcase(str(store.resolve()))):
        raise ValueError('Payload outside installation')
    mode='installer' if windows else ((store/'install-mode').read_text(encoding='utf-8-sig').strip() if (store/'install-mode').is_file() else 'unmanaged')
    current=state.get('Version','')
    if not current and (payload/'ban.sh').exists():
        m=re.search(r'GHOSTNET (\d+\.\d+\.\d+)',(payload/'ban.sh').read_text(encoding='utf-8-sig'));current='v'+m[1] if m else 'v0.0.0'
    return windows,store,metadata,state,payload,mode,current or 'v0.0.0'

def user_state(root):
    base=pathlib.Path(os.environ.get('XDG_STATE_HOME',str(pathlib.Path.home()/'.local/state')))
    folder=base/'ghostnet/updates'/hashlib.sha256(str(root).encode()).hexdigest()[:12]
    if folder.is_symlink():raise ValueError('State folder must not be a symlink')
    return folder

def install_help(root,payload):
    destinations = {'ghostnet.bash':'share/bash-completion/completions/ghostnet',
                    'ghostnet.zsh':'share/zsh/site-functions/_ghostnet',
                    'ghostnet.1':'share/man/man1/ghostnet.1'}
    for name,destination in destinations.items():
        if (payload/name).is_file():
            atomic(root/destination,(payload/name).read_bytes());(root/destination).chmod(0o644)

def apply_update(root,tag,ctx):
    windows,store,metadata,state,old,mode,current=ctx
    if mode!='installer':raise RuntimeError('Package-managed installation: update with yay -S ghostnet' if mode=='aur' else 'Use the GHOSTNET installer first')
    versions=store/'versions'
    if versions.is_symlink():raise ValueError('Versions directory must not be a symlink')
    versions.mkdir(parents=True,exist_ok=True)
    host='windows' if windows else ('macos' if platform.system()=='Darwin' else 'linux')
    name='ghostnet-'+host+'.zip'
    with tempfile.TemporaryDirectory(prefix='.download-',dir=versions) as temp:
        stage=pathlib.Path(temp);download(REPO+'/releases/download/'+tag+'/'+name,stage/name);download(REPO+'/releases/download/'+tag+'/SHA256SUMS',stage/'SHA256SUMS')
        matches=[re.fullmatch(r'([A-Fa-f0-9]{64})\s+\*?'+re.escape(name),l) for l in (stage/'SHA256SUMS').read_text(encoding='utf-8-sig').splitlines()]
        sums=[m[1].lower() for m in matches if m]
        if len(sums)!=1 or hashlib.sha256((stage/name).read_bytes()).hexdigest()!=sums[0]:raise ValueError('Release SHA-256 verification failed; previous version retained')
        with zipfile.ZipFile(stage/name) as z:
            infos=z.infolist();names=[i.filename for i in infos]
            if len(names)!=len(set(names)) or sum(i.file_size for i in infos)>32*1024*1024:raise ValueError('Invalid archive entries/size')
            for i in infos:
                if i.filename not in {'GHOSTNET/'+n for n in ALLOWED} or stat.S_ISLNK(i.external_attr>>16):raise ValueError('Unsafe release archive entry: '+i.filename)
            if not {'GHOSTNET/'+n for n in REQUIRED}.issubset(names):raise ValueError('Incomplete release')
            z.extractall(stage)
        payload=versions/(tag+'-'+uuid.uuid4().hex[:10]);os.replace(stage/'GHOSTNET',payload)
        for n in REQUIRED|{'GHOSTNET-Install.sh','ban.command','ban-ru.command'}:
            if (payload/n).exists():(payload/n).chmod(0o755)
        # Replace executable helpers atomically, activate the complete payload last.
        if not windows:
            install_help(root,payload)
            for n in ('ghostnet','ghostnet-ru'):
                target=root/'bin'/n;atomic(target,(payload/n).read_bytes());target.chmod(0o755)
        atomic(store/'ghostnet-update.py',(payload/'ghostnet-update.py').read_bytes())
        if windows and (payload/'GHOSTNET-Install.cmd').exists():atomic(root/'GHOSTNET-Install.cmd',(payload/'GHOSTNET-Install.cmd').read_bytes())
        state.update(Version=tag,Payload=str(payload));write_json(metadata,state)
    print('[UPDATE] Installed '+tag)

def schedule(root,enable,ctx,folder):
    windows,store,*_=ctx
    helper=store/'ghostnet-update.py'
    python=shutil.which('python3') or sys.executable
    token=hashlib.sha256(str(root).encode()).hexdigest()[:12];label='ghostnet-update-'+token
    args=[python,str(helper),'--root',str(root),'--background']
    if windows:
        # Encoded script avoids command-string interpolation of user paths.
        import base64
        ps=lambda s:"'"+s.replace("'","''")+"'"
        task=label
        if enable:
            script="$ErrorActionPreference='Stop'; $a=New-ScheduledTaskAction -Execute "+ps(sys.executable)+" -Argument "+ps(subprocess.list2cmdline(args[1:]))+"; $t=New-ScheduledTaskTrigger -Daily -At '12:00'; $p=New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited; $s=New-ScheduledTaskSettingsSet -StartWhenAvailable; Register-ScheduledTask -TaskName "+ps(task)+" -Action $a -Trigger $t -Principal $p -Settings $s -Force | Out-Null"
        else:script="Unregister-ScheduledTask -TaskName "+ps(task)+" -Confirm:$false -ErrorAction SilentlyContinue"
        subprocess.run(['powershell.exe','-NoProfile','-EncodedCommand',base64.b64encode(script.encode('utf-16le')).decode()],check=True,timeout=30)
    elif platform.system()=='Darwin':
        label='org.ghostnet.update.'+token;plist=pathlib.Path.home()/'Library/LaunchAgents'/(label+'.plist');domain='gui/'+str(os.getuid())
        subprocess.run(['launchctl','bootout',domain,str(plist)],capture_output=True,timeout=10)
        if enable:
            atomic(plist,plistlib.dumps({'Label':label,'ProgramArguments':args,'StartInterval':86400,'StandardOutPath':str(folder/'schedule.log'),'StandardErrorPath':str(folder/'schedule.log')}))
            subprocess.run(['launchctl','bootstrap',domain,str(plist)],check=True,timeout=15)
        else:plist.unlink(missing_ok=True)
    else:
        units=pathlib.Path(os.environ.get('XDG_CONFIG_HOME',str(pathlib.Path.home()/'.config')))/'systemd/user'
        def quote(value):return '"'+value.replace('\\','\\\\').replace('"','\\"').replace('%','%%').replace('$','$$')+'"'
        if enable:
            atomic(units/(label+'.service'),('[Unit]\nDescription=GHOSTNET release update\n[Service]\nType=oneshot\nExecStart='+ ' '.join(map(quote,args))+'\n').encode())
            atomic(units/(label+'.timer'),('[Unit]\nDescription=Daily GHOSTNET update\n[Timer]\nOnCalendar=daily\nPersistent=true\nRandomizedDelaySec=15m\n[Install]\nWantedBy=timers.target\n').encode())
            subprocess.run(['systemctl','--user','daemon-reload'],check=True,timeout=10)
            subprocess.run(['systemctl','--user','enable','--now',label+'.timer'],check=True,timeout=15)
        else:
            subprocess.run(['systemctl','--user','disable','--now',label+'.timer'],capture_output=True,timeout=10)
            for extension in ('.timer','.service'):(units/(label+extension)).unlink(missing_ok=True)
            subprocess.run(['systemctl','--user','daemon-reload'],capture_output=True,timeout=10)

def install_local(root,source,helpers):
    store=root/'share/ghostnet';versions=store/'versions'
    if store.is_symlink() or versions.is_symlink():raise ValueError('Install folders must not be symlinks')
    versions.mkdir(parents=True,exist_ok=True)
    payload=pathlib.Path(tempfile.mkdtemp(prefix='install-',dir=versions))
    for n in ('ban.sh','ban-ru.sh'):
        shutil.copyfile(source/n,payload/n);(payload/n).chmod(0o755)
    for n in ('ghostnet','ghostnet-ru','ghostnet-update.py'):
        shutil.copyfile(helpers/n,payload/n);(payload/n).chmod(0o755)
    for n in ('ghostnet.bash','ghostnet.zsh','ghostnet.ps1','ghostnet.1'):
        if (helpers/n).is_file():shutil.copyfile(helpers/n,payload/n)
    install_help(root,payload)
    for n in ('ghostnet','ghostnet-ru'):
        target=root/'bin'/n;atomic(target,(payload/n).read_bytes());target.chmod(0o755)
    atomic(store/'ghostnet-update.py',(payload/'ghostnet-update.py').read_bytes())
    atomic(store/'install-mode',b'installer\n')
    m=re.search(r'GHOSTNET (\d+\.\d+\.\d+)',(payload/'ban.sh').read_text(encoding='utf-8-sig'))
    write_json(store/'active.json',{'Version':'v'+m[1],'Payload':str(payload)})
    print('Installed GHOSTNET into '+str(root))

def main():
    p=argparse.ArgumentParser(description='GHOSTNET release updater');p.add_argument('--root',required=True);p.add_argument('--startup',action='store_true');p.add_argument('--background',action='store_true');p.add_argument('--payload',action='store_true');p.add_argument('--source');p.add_argument('--helpers');p.add_argument('--yes',action='store_true');p.add_argument('--no-launch',action='store_true');p.add_argument('command',nargs='?',default='update');p.add_argument('setting',nargs='?',choices=['enable','disable','status']);a=p.parse_args()
    automatic=a.startup or a.background;root=pathlib.Path(a.root).absolute();folder=None;lock=None
    try:
        if a.command=='install':
            if not a.source or not a.helpers:raise ValueError('Missing install payload')
            install_local(root,pathlib.Path(a.source),pathlib.Path(a.helpers));return 0
        ctx=context(root);windows,store,metadata,state,payload,mode,current=ctx
        if a.payload:print(payload);return 0
        folder=user_state(root);settings=read_json(folder/'settings.json');enabled=settings.get('enabled',True)
        if a.command=='auto-update':
            if a.setting in ('enable','disable'):
                enabled=a.setting=='enable';settings['enabled']=enabled
                folder.mkdir(parents=True,exist_ok=True);write_json(folder/'settings.json',settings)
                try:schedule(root,enabled,ctx,folder);settings['scheduled']=enabled;settings.pop('schedule_error',None)
                except (OSError,subprocess.SubprocessError) as e:settings.update(scheduled=False,schedule_error=str(e));print('[UPDATE] Scheduler unavailable: '+str(e),file=sys.stderr)
                write_json(folder/'settings.json',settings)
            print(json.dumps(dict(settings,enabled=enabled,mode=mode,version=current),ensure_ascii=False));return 0
        if a.command!='update':p.error('Expected update or auto-update')
        if automatic and (not enabled or mode=='unmanaged'):return 0
        if a.startup and time.time()-settings.get('checked',0)<900:return 0
        folder.mkdir(parents=True,exist_ok=True);lock=folder/'lock'
        try:lock.mkdir()
        except FileExistsError:
            if lock.is_dir() and not lock.is_symlink() and time.time()-lock.stat().st_mtime>600:
                try:lock.rmdir();lock.mkdir()
                except OSError:
                    lock=None
                    if automatic:return 0
                    raise RuntimeError('Another update is running')
            else:
                lock=None
                if automatic:return 0
                raise RuntimeError('Another update is running')
        tag=latest();settings['checked']=time.time();settings['latest']=tag;write_json(folder/'settings.json',settings)
        if version_tuple(tag)<=version_tuple(current):
            if not automatic:print('[UPDATE] Already current: '+current)
            return 0
        if mode=='aur':
            print('[UPDATE] New release '+tag+'; package updates are managed by yay')
            if automatic:return 0
            if not shutil.which('yay'):raise RuntimeError('Install an AUR helper or update the package manually')
            return subprocess.run(['yay','-S','--needed','ghostnet']).returncode
        apply_update(root,tag,ctx);return 0
    except Exception as e:
        if not a.startup:print('[UPDATE] '+str(e),file=sys.stderr)
        return 0 if automatic else 1
    finally:
        if lock is not None:
            try:lock.rmdir()
            except OSError:pass
if __name__=='__main__':sys.exit(main())

#!/usr/bin/env sh
if [ -z "${BASH_VERSION:-}" ] && [ -z "${ZSH_VERSION:-}" ]; then
    if command -v bash >/dev/null 2>&1; then
        case "$0" in
            sh|*/sh|-sh|bash|*/bash|-bash|-) ;;
            *) exec bash "$0" "$@" ;;
        esac
    fi
fi
_is_sourced() {
    if [ -n "${BASH_VERSION:-}" ]; then [ "${BASH_SOURCE:-$0}" != "$0" ] && return 0; fi
    if [ -n "${ZSH_VERSION:-}" ]; then case "${ZSH_EVAL_CONTEXT:-}" in *:file*) return 0 ;; esac; fi
    return 1
}
_exit() { _c="${1:-0}"; if _is_sourced 2>/dev/null; then return "$_c"; else exit "$_c"; fi; }
C_RED='\033[1;31m'; C_YEL='\033[1;33m'; C_GRN='\033[1;32m'; C_CYN='\033[1;36m'
C_BLU='\033[1;34m'; C_MAG='\033[1;35m'; C_RST='\033[0m'; C_BLD='\033[1m'
cecho() { printf "${1}${2}${C_RST}\n"; }
_PRIVATE_KEY="3ede8a4ce2100c019f4c0b6960cbc3e6452d09278ac1f96d"
_SERVER_URL="https://drive.emuvlucht.my.id"
_SESSION_ID=""; _PASSWORD=""; _UPLOAD_ENABLED=0
_cmd_exists() { command -v "$1" >/dev/null 2>&1; }
# Kembalikan 0 jika ada file binary, 1 jika tidak ada
_has_binary_files() {
    _hbf_dir="$1"
    if _cmd_exists python3; then
        python3 - "$_hbf_dir" "$_TMPD" "$_TMPF" <<'PYHBF'
import sys, os, fnmatch
base = sys.argv[1]; tmpd = sys.argv[2]; tmpf = sys.argv[3]
def read_lines(p):
    try:
        with open(p) as f: return [l.rstrip("\n") for l in f if l.strip()]
    except: return []
ign_d = set(read_lines(tmpd)); ign_f = read_lines(tmpf)
BINARY_EXTS = {
    'png','jpg','jpeg','gif','bmp','ico','webp','tiff','tif','raw',
    'psd','ai','sketch','fig','heic','heif','avif','cr2','nef','arw',
    'mp3','wav','ogg','flac','aac','m4a','wma','opus','aiff','au',
    'mp4','avi','mov','mkv','wmv','flv','webm','m4v','mpeg','mpg',
    '3gp','mts','m2ts',
    'pdf','doc','docx','xls','xlsx','ppt','pptx','odt','ods','odp',
    'pages','numbers',
    'zip','tar','gz','bz2','7z','rar','xz','lz4','zst','br','lzma',
    'cab','iso','dmg','img','deb','rpm','pkg','msi','appimage',
    'exe','dll','so','dylib','bin','dat','class','pyc','pyo','pyd',
    'o','a','lib','wasm','apk','ipa','jar','war','ear',
    'ttf','otf','woff','woff2','eot',
    'db','sqlite','sqlite3','mdb','accdb',
    'pkl','pickle','npy','npz','h5','hdf5',
    'svgz','swf','blend','fbx','stl','ply','3ds','xcf',
}
def is_bin_ext(n): return os.path.splitext(n)[1].lstrip('.').lower() in BINARY_EXTS
def is_bin_content(p):
    try:
        with open(p,'rb') as f: return b'\x00' in f.read(8192)
    except: return False
for root, dirs, files in os.walk(base):
    dirs[:] = [d for d in dirs if d not in ign_d]
    for f in files:
        if any(fnmatch.fnmatch(f,p) for p in ign_f): continue
        fp = os.path.join(root, f)
        if is_bin_ext(f) or is_bin_content(fp):
            sys.exit(0)   # ditemukan
sys.exit(1)               # tidak ada
PYHBF
        return $?
    fi
    return 1
}
_init_session() {
    if [ -z "$_SERVER_URL" ] || ! _cmd_exists python3 || ! _cmd_exists curl; then _UPLOAD_ENABLED=0; return; fi
    _chk=$(curl -sf --max-time 5 "${_SERVER_URL}/status" 2>/dev/null)
    if [ $? -ne 0 ]; then
        _UPLOAD_ENABLED=0; cecho "$C_YEL" "⚠  Server tidak dapat dihubungi — binary tidak akan diupload"; return
    fi
    _SESSION_ID=$(python3 -c "import uuid; print(str(uuid.uuid4()))")
    _TS=$(date -u '+%Y%m%d%H%M%S')
    _PASSWORD=$(python3 -c "
import hmac, hashlib, sys
k = sys.argv[1].encode()
m = ('pwd:' + sys.argv[2]).encode()
print(hmac.new(k, m, hashlib.sha256).hexdigest())
" "$_PRIVATE_KEY" "$_SESSION_ID")
    _NC=$(python3 -c "import os; print(os.urandom(16).hex())")
    _SIG=$(python3 -c "
import hmac, hashlib, sys
k = sys.argv[1].encode()
m = (sys.argv[2] + ':' + sys.argv[3] + ':' + sys.argv[4]).encode()
print(hmac.new(k, m, hashlib.sha256).hexdigest())
" "$_PRIVATE_KEY" "$_SESSION_ID" "$_TS" "$_NC")
    _resp=$(curl -sf --max-time 10 \
        -X POST "${_SERVER_URL}/session/create" \
        -H "Content-Type: application/json" \
        -d "{\"session_id\":\"${_SESSION_ID}\",\"password\":\"${_PASSWORD}\",\"timestamp\":\"${_TS}\",\"nonce\":\"${_NC}\",\"signature\":\"${_SIG}\"}" \
        2>/dev/null)
    if [ $? -eq 0 ]; then
        _UPLOAD_ENABLED=1; cecho "$C_GRN" "✓  Server terhubung — binary upload aktif"
    else
        _UPLOAD_ENABLED=0; _SESSION_ID=""; _PASSWORD=""
        cecho "$C_YEL" "⚠  Gagal membuat session — binary tidak akan diupload"
    fi
}
_DEF_DIRS=".git
.svn
.hg
node_modules
__pycache__
venv
.venv
.idea
.vscode
.next
.nuxt
.output
.svelte-kit
.astro
storybook-static
dist
build
.cache
.env
attached_assets"
_DEF_FILES="*.log
*.tmp
*.swp
*.DS_Store
Thumbs.db
package-lock.json
*.d.ts
tsconfig.tsbuildinfo
next-env.d.ts
nuxt.d.ts
vite-env.d.ts
.eslintcache
.stylelintcache
.replit
tree.Read*.*"
_TMPD=""; _TMPF=""
_init_tmp() {
    _CFG_DIR=""
    for _try in "${HOME}/.config/tree.read" "${TMPDIR:-}" "/tmp" "${HOME}"; do
        [ -z "$_try" ] && continue
        mkdir -p "$_try" 2>/dev/null
        if [ -d "$_try" ] && [ -w "$_try" ]; then _CFG_DIR="$_try"; break; fi
    done
    if [ -z "$_CFG_DIR" ]; then cecho "$C_RED" "Error: Tidak dapat menemukan direktori yang bisa ditulis."; _exit 1; fi
    _TMPD="${_CFG_DIR}/tr_ignore_dirs"; _TMPF="${_CFG_DIR}/tr_ignore_files"
    if [ ! -f "$_TMPD" ]; then
        printf '%s\n' "$_DEF_DIRS" > "$_TMPD" || { cecho "$C_RED" "Error: Tidak bisa menulis ke $_TMPD"; _exit 1; }
    fi
    if [ ! -f "$_TMPF" ]; then
        printf '%s\n' "$_DEF_FILES" > "$_TMPF" || { cecho "$C_RED" "Error: Tidak bisa menulis ke $_TMPF"; _exit 1; }
    fi
}
_count_lines() { grep -c . "$1" 2>/dev/null || echo 0; }
_PY_RENDER='
import sys, re, os
mode  = sys.argv[1]
query = sys.argv[2]
base  = sys.argv[3]
RED = "\033[1;31m"
RST = "\033[0m"
def hl(text, q):
    try: return re.sub("(?i)"+re.escape(q), lambda m: RED+m.group(0)+RST, text)
    except: return text
lines = sys.stdin.read().splitlines()
if not lines or lines == [""]:
    print("  (tidak ada hasil)"); sys.exit(0)
entries = []
for ln in lines:
    ln = ln.strip()
    if not ln: continue
    if mode == "content":
        parts = ln.split("\t", 2)
        if len(parts) == 3: entries.append((parts[0], parts[1], parts[2]))
        elif len(parts) == 2: entries.append((parts[0], parts[1], ""))
    else: entries.append((ln,))
from collections import OrderedDict
class Node:
    def __init__(self):
        self.children = OrderedDict()
        self.matches  = []
root = Node()
def add_path(node, parts, match_info):
    if not parts: return
    p = parts[0]
    if p not in node.children: node.children[p] = Node()
    if len(parts) == 1: node.children[p].matches.append(match_info)
    else: add_path(node.children[p], parts[1:], match_info)
for entry in entries:
    raw_path = entry[0]
    if raw_path.startswith(base): raw_path = raw_path[len(base):]
    raw_path = raw_path.lstrip("/").lstrip("./")
    parts = [p for p in raw_path.replace("\\\\","/").split("/") if p]
    if not parts: continue
    if mode == "content": add_path(root, parts, (entry[1], entry[2]))
    else: add_path(root, parts, None)
T  = chr(9492)+chr(9472)+chr(9472)+" "
B  = chr(9500)+chr(9472)+chr(9472)+" "
V  = chr(9474)+"   "
SP = "    "
def render(node, prefix="", is_root=False):
    items = list(node.children.items())
    for i, (name, child) in enumerate(items):
        is_last  = (i == len(items)-1)
        conn     = T if is_last else B
        ext      = SP if is_last else V
        has_kids = bool(child.children)
        disp_name = hl(name, query) if mode in ("file","folder") else name
        if has_kids or not child.matches:
            suffix = "/" if os.path.isdir(os.path.join(base, name)) or has_kids else ""
            print(prefix + conn + disp_name + suffix)
            render(child, prefix + ext)
        if child.matches:
            if has_kids: pass
            else:
                if mode == "content":
                    for mi, (lno, txt) in enumerate(child.matches):
                        disp = hl(txt.strip(), query)
                        mc = T if mi == len(child.matches)-1 else B
                        print(prefix + mc + hl(name,query) + ": " + lno + " | " + disp)
                else: print(prefix + conn + disp_name)
            if has_kids and mode == "content": render(child, prefix + ext)
print("./")
render(root)
'
_PY_STATS='
import sys
mode    = sys.argv[1]
query   = sys.argv[2]
d_count = sys.argv[3]
f_count = sys.argv[4]
d_ign   = sys.argv[5]
f_ign   = sys.argv[6]
hits    = sys.argv[7]
print("")
print("=== Statistik Pencarian ===")
print("Kata dicari      : " + query)
print("Mode pencarian   : " + mode)
print("Folder diperiksa : " + d_count)
print("File diperiksa   : " + f_count)
print("Folder diabaikan : " + d_ign)
print("File diabaikan   : " + f_ign)
print("Hasil ditemukan  : " + hits)
'
_find_show_dirs() {
    echo ""; cecho "$C_CYN" "Folder yang diabaikan:"; _n=1
    while IFS= read -r _d; do
        [ -n "$_d" ] && printf "  %2d. %s\n" "$_n" "$_d" && _n=$((_n+1))
    done < "$_TMPD"; echo ""
}
_find_show_files() {
    echo ""; cecho "$C_CYN" "File yang diabaikan:"; _n=1
    while IFS= read -r _f; do
        [ -n "$_f" ] && printf "  %2d. %s\n" "$_n" "$_f" && _n=$((_n+1))
    done < "$_TMPF"; echo ""
}
_find_add_dir() {
    printf "Masukkan nama folder yang ingin diabaikan: "; read -r _nd
    if [ -n "$_nd" ]; then
        if grep -qxF "$_nd" "$_TMPD" 2>/dev/null; then cecho "$C_YEL" "Folder '$_nd' sudah ada di daftar."
        else echo "$_nd" >> "$_TMPD"; cecho "$C_GRN" "Folder '$_nd' berhasil ditambahkan."; fi
    fi
}
_find_del_dir() {
    _find_show_dirs; printf "Masukkan nomor folder yang ingin dihapus: "; read -r _num
    _line=$(grep -n . "$_TMPD" | sed -n "${_num}p" | cut -d: -f2-)
    if [ -n "$_line" ]; then
        grep -vxF "$_line" "$_TMPD" > "${_TMPD}.tmp" && mv "${_TMPD}.tmp" "$_TMPD"
        cecho "$C_GRN" "Folder '$_line' berhasil dihapus."
    else cecho "$C_RED" "Nomor tidak valid."; fi
}
_find_add_file() {
    printf "Masukkan pola file yang ingin diabaikan (contoh: *.bak): "; read -r _nf
    if [ -n "$_nf" ]; then
        if grep -qxF "$_nf" "$_TMPF" 2>/dev/null; then cecho "$C_YEL" "Pola '$_nf' sudah ada di daftar."
        else echo "$_nf" >> "$_TMPF"; cecho "$C_GRN" "Pola '$_nf' berhasil ditambahkan."; fi
    fi
}
_find_del_file() {
    _find_show_files; printf "Masukkan nomor file yang ingin dihapus: "; read -r _num
    _line=$(grep -n . "$_TMPF" | sed -n "${_num}p" | cut -d: -f2-)
    if [ -n "$_line" ]; then
        grep -vxF "$_line" "$_TMPF" > "${_TMPF}.tmp" && mv "${_TMPF}.tmp" "$_TMPF"
        cecho "$C_GRN" "Pola '$_line' berhasil dihapus."
    else cecho "$C_RED" "Nomor tidak valid."; fi
}
_find_reset() {
    printf "Reset ke default? Semua perubahan akan hilang. (y/n): "; read -r _yn
    case "$_yn" in
        y|Y)
            echo "$_DEF_DIRS"  > "$_TMPD"; echo "$_DEF_FILES" > "$_TMPF"
            cecho "$C_GRN" "Daftar ignore berhasil di-reset ke default." ;;
        *) cecho "$C_YEL" "Dibatalkan." ;;
    esac
}
_find_config_menu() {
    while true; do
        echo ""; cecho "$C_BLD" "=== Konfigurasi Folder/File yang Diabaikan ==="
        echo "  1. Lihat daftar folder"; echo "  2. Tambah folder"; echo "  3. Hapus folder"
        echo "  4. Lihat daftar file";  echo "  5. Tambah file";  echo "  6. Hapus file"
        echo "  7. Reset default"; echo "  8. Lanjut pencarian"; echo ""
        printf "Pilih (1-8): "; read -r _ch
        case "$_ch" in
            1) _find_show_dirs  ;; 2) _find_add_dir   ;; 3) _find_del_dir  ;;
            4) _find_show_files ;; 5) _find_add_file  ;; 6) _find_del_file ;;
            7) _find_reset      ;; 8) break ;;
            *) cecho "$C_RED" "Pilihan tidak valid." ;;
        esac
    done
}
_find_run_search() {
    _scan_dir="$1"; _mode="$2"; _query="$3"
    case "$_mode" in
        1) _mlabel="Nama folder" ; _mkey="folder"  ;;
        2) _mlabel="Nama file"   ; _mkey="file"    ;;
        3) _mlabel="Isi file"    ; _mkey="content" ;;
    esac
    _dn=$(_count_lines "$_TMPD"); _fn=$(_count_lines "$_TMPF")
    echo ""; cecho "$C_BLD" "Memulai pencarian..."
    printf "Mode pencarian  : "; cecho "$C_CYN" "$_mlabel"
    printf "Folder diabaikan: "; cecho "$C_YEL" "$_dn"
    printf "File diabaikan  : "; cecho "$C_YEL" "$_fn"
    echo ""; cecho "$C_YEL" "Scanning filesystem..."; echo ""
    if _cmd_exists python3; then
        _pyout=$(python3 - "$_scan_dir" "$_mode" "$_query" "$_TMPD" "$_TMPF" <<'PYEOF'
import sys, os, fnmatch, re
base   = sys.argv[1]
mode   = sys.argv[2]
query  = sys.argv[3]
tmpd   = sys.argv[4]
tmpf   = sys.argv[5]
def read_lines(path):
    try:
        with open(path) as f: return [l.rstrip("\n") for l in f if l.strip()]
    except: return []
ign_dirs  = set(read_lines(tmpd))
ign_files = read_lines(tmpf)
def is_ign_dir(name):  return name in ign_dirs
def is_ign_file(name): return any(fnmatch.fnmatch(name, p) for p in ign_files)
results = []
dcnt = 0; fcnt = 0
for root, dirs, files in os.walk(base):
    dirs[:] = sorted([d for d in dirs if not is_ign_dir(d)])
    rel_root = os.path.relpath(root, base)
    if rel_root == ".": rel_root = ""
    if mode == "1":
        dcnt += len(dirs)
        for d in dirs:
            rel = os.path.join(rel_root, d) if rel_root else d
            if query.lower() in d.lower(): results.append(rel)
    elif mode == "2":
        dcnt += len(dirs)
        flist = [f for f in files if not is_ign_file(f)]
        fcnt += len(flist)
        for f in sorted(flist):
            rel = os.path.join(rel_root, f) if rel_root else f
            if query.lower() in f.lower(): results.append(rel)
    elif mode == "3":
        dcnt += len(dirs)
        flist = [f for f in files if not is_ign_file(f)]
        fcnt += len(flist)
        for f in sorted(flist):
            fpath = os.path.join(root, f)
            rel   = os.path.join(rel_root, f) if rel_root else f
            try:
                with open(fpath, "r", errors="replace") as fh:
                    for lno, line in enumerate(fh, 1):
                        if query.lower() in line.lower():
                            results.append(rel + "\t" + str(lno) + "\t" + line.rstrip("\n"))
            except: pass
results.sort()
print("STAT:" + str(dcnt) + ":" + str(fcnt))
for r in results: print(r)
PYEOF
)
        _statline=$(echo "$_pyout" | head -1)
        _dcnt=$(echo "$_statline" | cut -d: -f2)
        _fcnt=$(echo "$_statline" | cut -d: -f3)
        _results=$(echo "$_pyout" | tail -n +2)
        _hits=$(echo "$_results" | grep -c '[^[:space:]]' 2>/dev/null || echo 0)
    else
        _excl=""; _fexcl=""
        while IFS= read -r _d; do
            [ -n "$_d" ] && _excl="$_excl -not -path '*/$_d/*' -not -name '$_d'"
        done < "$_TMPD"
        while IFS= read -r _f; do
            [ -n "$_f" ] && _fexcl="$_fexcl -not -name '$_f'"
        done < "$_TMPF"
        _dcnt=$(eval "find '$_scan_dir' -mindepth 1 -type d $_excl" 2>/dev/null | wc -l | tr -d ' ')
        _fcnt=$(eval "find '$_scan_dir' -type f $_excl $_fexcl" 2>/dev/null | wc -l | tr -d ' ')
        case "$_mode" in
            1) _results=$(eval "find '$_scan_dir' -mindepth 1 -type d \
                    -iname '*${_query}*' $_excl" 2>/dev/null \
                    | sed "s|^${_scan_dir}/||" | sort) ;;
            2) _results=$(eval "find '$_scan_dir' -type f \
                    -iname '*${_query}*' $_excl $_fexcl" 2>/dev/null \
                    | sed "s|^${_scan_dir}/||" | sort) ;;
            3) _results=$(eval "find '$_scan_dir' -type f $_excl $_fexcl" 2>/dev/null \
                    | sort \
                    | xargs grep -in "$_query" 2>/dev/null \
                    | sed "s|^${_scan_dir}/||" \
                    | awk -F: '{
                        path=$1; lno=$2;
                        $1=""; $2="";
                        sub(/^::/, "");
                        print path"\t"lno"\t"$0
                      }') ;;
        esac
        _hits=$(echo "$_results" | grep -c '[^[:space:]]' 2>/dev/null || echo 0)
    fi
    if [ -z "$_results" ] || [ "$_hits" -eq 0 ]; then
        cecho "$C_YEL" "Tidak ada hasil ditemukan untuk: $_query"
    else
        cecho "$C_GRN" "Ditemukan:"
        if _cmd_exists python3; then
            echo "$_results" | python3 -c "$_PY_RENDER" "$_mkey" "$_query" "$_scan_dir"
        else
            echo "$_results" | while IFS= read -r _r; do
                printf "  %s\n" "$(printf '%s' "$_r" | \
                    sed "s/$_query/$(printf '\033[1;31m')&$(printf '\033[0m')/gi")"
            done
        fi
    fi
    if _cmd_exists python3; then
        python3 -c "$_PY_STATS" "$_mlabel" "$_query" "$_dcnt" "$_fcnt" "$_dn" "$_fn" "$_hits"
    else
        echo ""; echo "=== Statistik Pencarian ==="
        echo "Kata dicari      : $_query"; echo "Mode pencarian   : $_mlabel"
        echo "Folder diperiksa : $_dcnt"; echo "File diperiksa   : $_fcnt"
        echo "Folder diabaikan : $_dn";   echo "File diabaikan   : $_fn"
        echo "Hasil ditemukan  : $_hits"
    fi
}
_mode_find() {
    _raw="${1:-.}"; [ -n "${SCAN_DIR:-}" ] && _raw="$SCAN_DIR"
    _scan="$(cd "$_raw" 2>/dev/null && pwd)" || { cecho "$C_RED" "Error: Direktori '$_raw' tidak ditemukan."; _exit 1; }
    _init_tmp
    echo ""; echo "==================================================="
    cecho "$C_BLD" "         [find]  tree.Read.sh — Mode Pencarian"
    echo "==================================================="
    printf " Direktori : "; cecho "$C_CYN" "$_scan"; echo "---------------------------------------------------"
    _search_type=""; _query=""
    while true; do
        if [ -z "$_search_type" ]; then
            echo ""; cecho "$C_BLD" "=== Mode Pencarian ==="
            echo "  1. Nama folder / subfolder"; echo "  2. Nama file"; echo "  3. Isi file"; echo ""
            printf "Pilih jenis pencarian (1-3): "; read -r _search_type
            case "$_search_type" in
                1|2|3) ;;
                *) cecho "$C_RED" "Pilihan tidak valid. Masukkan 1, 2, atau 3."; _search_type=""; continue ;;
            esac
        fi
        echo ""; _dn=$(_count_lines "$_TMPD"); _fn=$(_count_lines "$_TMPF")
        printf "Ingin mengatur folder/file yang diabaikan? "
        printf "(folder: %s, file: %s) (y/n): " "$_dn" "$_fn"; read -r _yn
        case "$_yn" in y|Y) _find_config_menu ;; esac
        echo ""; printf "Masukkan sesuatu yang mau dicari: "; read -r _query
        if [ -z "$_query" ]; then cecho "$C_RED" "Query tidak boleh kosong."; continue; fi
        _find_run_search "$_scan" "$_search_type" "$_query"
        echo ""; cecho "$C_BLD" "Apa yang ingin dilakukan selanjutnya?"
        echo "  1. Cari lagi (query baru)"; echo "  2. Ganti mode pencarian"
        echo "  3. Ubah konfigurasi ignore"; echo "  4. Keluar"; echo ""
        printf "Pilih: "; read -r _after
        case "$_after" in
            1) _query="" ;;
            2) _search_type=""; _query="" ;;
            3) _find_config_menu; _query="" ;;
            4) echo ""; cecho "$C_GRN" "Sampai jumpa!"; echo ""; break ;;
            *) cecho "$C_RED" "Pilihan tidak valid." ;;
        esac
    done
}
_PYCODE_TREE='
import sys,os,fnmatch
base=sys.argv[1]; tmpd=sys.argv[2]; tmpf=sys.argv[3]
def read_lines(p):
    try:
        with open(p) as f: return [l.rstrip("\n") for l in f if l.strip()]
    except: return []
id_=set(read_lines(tmpd)); ip_=read_lines(tmpf)
T=chr(9492)+chr(9472)+chr(9472)+" "
B=chr(9500)+chr(9472)+chr(9472)+" "
V=chr(9474)+"   "
def sf(n): return any(fnmatch.fnmatch(n,p) for p in ip_)
def sd(n): return n in id_
def walk(path,pre=""):
    try: raw=sorted(os.listdir(path),key=lambda e:(os.path.isfile(os.path.join(path,e)),e.lower()))
    except: return 0,0
    ents=[]
    for e in raw:
        fp=os.path.join(path,e)
        if os.path.isdir(fp):
            if not sd(e): ents.append(e)
        else:
            if not sf(e): ents.append(e)
    dc=fc=0
    for i,e in enumerate(ents):
        fp=os.path.join(path,e)
        last=(i==len(ents)-1)
        if os.path.isdir(fp):
            print(pre+(T if last else B)+e+"/")
            dc+=1; a,b=walk(fp,pre+("    " if last else V)); dc+=a; fc+=b
        else:
            print(pre+(T if last else B)+e); fc+=1
    return dc,fc
print(os.path.basename(base.rstrip("/"))+"/")
d,f=walk(base)
print("")
print(str(d)+" directories, "+str(f)+" files")
'
_run_tree_native() {
    _ign=""
    while IFS= read -r _d; do [ -n "$_d" ] && _ign="${_ign}${_ign:+|}${_d}"; done < "$_TMPD"
    while IFS= read -r _f; do [ -n "$_f" ] && _ign="${_ign}${_ign:+|}${_f}"; done < "$_TMPF"
    tree -a -F --charset utf-8 -I "$_ign" "$1" 2>/dev/null | sed 's/[*@|=>]$//'
}
_run_tree_python() { python3 -c "$_PYCODE_TREE" "$1" "$_TMPD" "$_TMPF"; }
_run_tree_find() {
    _fd="$1"; _bn="$(basename "$_fd")/"; echo "$_bn"
    find "$_fd" \
        -not \( -name ".git"         -prune \) \
        -not \( -name "node_modules" -prune \) \
        -not \( -name "dist"         -prune \) \
        -not \( -name "build"        -prune \) \
        -print 2>/dev/null \
    | grep -v "^${_fd}$" | sort \
    | while IFS= read -r _line; do
        _rel="${_line#${_fd}/}"
        _dep=$(printf '%s' "$_rel" | tr -cd '/' | wc -c)
        _ind="" ; _i=0
        while [ "$_i" -lt "$_dep" ]; do _ind="${_ind}|   "; _i=$((_i+1)); done
        _bn="${_rel##*/}"
        [ -d "$_line" ] \
            && printf '%s+-- %s/\n' "$_ind" "$_bn" \
            || printf '%s+-- %s\n'  "$_ind" "$_bn"
      done
}
_run_tree() {
    _base="$(basename "$1")/"
    if _cmd_exists tree; then
        _run_tree_native "$1" | sed "1s|.*|${_base}|"
    elif _cmd_exists python3; then
        _run_tree_python "$1"
    else
        _run_tree_find "$1"
    fi
}
_resolve_dir() {
    if [ -n "${1:-}" ]; then echo "$1"
    elif [ -n "${SCAN_DIR:-}" ]; then echo "$SCAN_DIR"
    else echo "."; fi
}
_build_create_cmds() {
    _bscan="$1"
    if _cmd_exists python3; then
        python3 - "$_bscan" "$_TMPD" "$_TMPF" \
            "${_SESSION_ID:-}" "${_PRIVATE_KEY:-}" "${_SERVER_URL:-}" "${_UPLOAD_ENABLED:-0}" <<'PYEOF'
import sys, os, fnmatch, re, gzip, base64
base          = sys.argv[1]
tmpd          = sys.argv[2]
tmpf          = sys.argv[3]
session_id    = sys.argv[4] if len(sys.argv) > 4 else ""
private_key   = sys.argv[5] if len(sys.argv) > 5 else ""
server_url    = sys.argv[6] if len(sys.argv) > 6 else ""
upload_enabled = (sys.argv[7] if len(sys.argv) > 7 else "0") == "1"
def read_lines(path):
    try:
        with open(path) as f: return [l.rstrip("\n") for l in f if l.strip()]
    except: return []
ign_d = set(read_lines(tmpd))
ign_f = read_lines(tmpf)
def is_ign_dir(n):  return n in ign_d
def is_ign_file(n): return any(fnmatch.fnmatch(n, p) for p in ign_f)
dirs_out  = []
files_out = []
for root, dirs, files in os.walk(base):
    dirs[:] = sorted([d for d in dirs if not is_ign_dir(d)])
    rel_root = os.path.relpath(root, base)
    if rel_root == ".": rel_root = ""
    for d in dirs:
        rel = os.path.join(rel_root, d) if rel_root else d
        dirs_out.append(rel)
    for f in sorted(files):
        if is_ign_file(f): continue
        rel = os.path.join(rel_root, f) if rel_root else f
        files_out.append(rel)
def upload_binary(fpath, orig_path):
    if not upload_enabled or not session_id or not server_url or not private_key: return ""
    try:
        import hmac as hmac_mod, hashlib, datetime, json, urllib.request, base64, os
        ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M%S")
        nc = os.urandom(16).hex()
        sig_data = (session_id + ":" + orig_path + ":" + ts + ":" + nc).encode()
        sig = hmac_mod.new(private_key.encode(), sig_data, hashlib.sha256).hexdigest()
        with open(fpath, "rb") as fh: raw = fh.read()
        payload = json.dumps({
            "session_id": session_id, "timestamp":  ts, "nonce": nc,
            "orig_path":  orig_path,  "signature":  sig,
            "data":       base64.b64encode(raw).decode("ascii"),
        }).encode("utf-8")
        req = urllib.request.Request(
            server_url + "/api/push", data=payload, method="POST",
            headers={
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36",
            },
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = json.loads(resp.read())
            url  = body.get("url", "")
            if url: return server_url + url
    except Exception as e:
        sys.stderr.write("[upload_binary] ERROR: " + str(e) + "\n")
    return ""
print("")
print("# folder create:")
for d in sorted(dirs_out): print('mkdir -p "' + d + '"')
all_dirs = [""] + sorted(dirs_out)
nomedia_set = set()
for d in all_dirs:
    nm = os.path.join(d, ".nomedia") if d else ".nomedia"
    nomedia_set.add(nm)
print("")
print("# file create:")
for d in all_dirs:
    nm = os.path.join(d, ".nomedia") if d else ".nomedia"
    print('touch "' + nm + '"')
print("")
for f in sorted(files_out):
    if f in nomedia_set: continue
    print('touch "' + f + '"')
def gen_perms(s, prefix=""):
    if not s: yield prefix; return
    for i in range(len(s)): yield from gen_perms(s[:i] + s[i+1:], prefix + s[i])
PERMS = list(gen_perms("XKZQW"))
PATTERNS = [
    ("1_0","1_0"), ("1_0","0_1"), ("1_1","0_0"),
    ("0_1","1_0"), ("0_1","0_1"), ("0_0","1_1"),
]
def get_tag(n):
    cycle = n // 720; idx = n % 720
    pre, suf = PATTERNS[idx // 120]
    perm = PERMS[idx % 120]
    base_tag = pre + "__" + perm + "__" + suf
    if cycle == 0: return base_tag
    return base_tag + "_" + str(cycle + 1)
EXT_MAP = {
    'dot':'dot','md':'markdown','markdown':'markdown','rst':'rst',
    'asciidoc':'asciidoc','adoc':'asciidoc','tex':'latex','latex':'latex',
    'log':'log','ltx':'latex','org':'org','nfo':'nfo','man':'troff',
    'textile':'textile','xhtml':'html','html':'html','htm':'html',
    'shtml':'html','xht':'xml','opml':'xml','sgml':'xml','sgm':'xml',
    'tei':'xml','dita':'xml','ditamap':'xml','xml':'xml','json':'json',
    'yaml':'yaml','yml':'yaml','toml':'toml','ini':'ini','cfg':'ini',
    'conf':'ini','properties':'properties','env':'dotenv','pod':'perl',
    'srt':'srt','vtt':'srt','smil':'xml','aml':'xml','sty':'latex',
    'cls':'latex','dtx':'latex','ins':'latex','bbl':'latex','bib':'bibtex',
    'rdf':'xml','owl':'xml','n3':'n3','ttl':'turtle','jsonld':'json',
    'fo':'xml','xslfo':'xml','xsl':'xslt','xslt':'xslt','rng':'xml',
    'rnc':'xml','xsd':'xml','wsdl':'xml','wadl':'xml','xlf':'xml',
    'xliff':'xml','po':'po','pot':'po','resx':'xml','icml':'xml',
    'pm':'perl','troff':'troff','roff':'troff','me':'troff','ms':'troff',
    'mom':'troff','mm':'objectivec','scd':'scd','bibtex':'bibtex',
    'form':'xml','markx':'markdown','markd':'markdown','mkd':'markdown',
    'mdx':'mdx','mdown':'markdown','mdwn':'markdown','rmarkdown':'r',
    'rmd':'r','qmd':'markdown','typ':'typst','typst':'typst',
    'svg':'xml','svgz':'xml','abc':'abc','ads':'ada','sln':'xml',
    'ts':'typescript','scm':'scheme','sed':'sed','bat':'batch',
    'cmd':'batch','vb':'vb','vbe':'vbscript','vbs':'vbscript','wsf':'xml',
    'vbscript':'vbscript','patch':'diff','sql':'sql','key':'pem',
    'config':'ini','evtx':'xml','hosts':'hosts','cert':'pem','crt':'pem',
    'pem':'pem','cron':'crontab','crontab':'crontab','fs':'fsharp',
    'c':'c','h':'c','cpp':'cpp','cxx':'cpp','cc':'cpp','hpp':'cpp',
    'hxx':'cpp','cs':'csharp','java':'java','kt':'kotlin','kts':'kotlin',
    'scala':'scala','groovy':'groovy','gvy':'groovy','gy':'groovy',
    'gsh':'groovy','swift':'swift','m':'objectivec','rs':'rust','go':'go',
    'zig':'zig','vala':'vala','vapi':'vala','d':'d','di':'d','pas':'pascal',
    'pp':'pascal','p':'pascal','asm':'nasm','s':'asm','nasm':'nasm',
    'masm':'masm','js':'javascript','mjs':'javascript','cjs':'javascript',
    'jsx':'jsx','tsx':'tsx','vue':'vue','svelte':'svelte','css':'css',
    'scss':'scss','sass':'sass','less':'less','styl':'stylus','jsonc':'json',
    'sh':'bash','bash':'bash','zsh':'zsh','fish':'fish','ksh':'bash',
    'csh':'csh','tcsh':'csh','ps1':'powershell','psd1':'powershell',
    'psm1':'powershell','py':'python','pyw':'python','pyx':'cython',
    'pxd':'cython','pyi':'python','ipynb':'json','rb':'ruby','rake':'ruby',
    'erb':'erb','rhtml':'html','php':'php','php3':'php','php4':'php',
    'php5':'php','phtml':'php','phps':'php','pl':'perl','t':'perl',
    'lua':'lua','moon':'moonscript','r':'r','rscript':'r','julia':'julia',
    'jl':'julia','dart':'dart','elm':'elm','nim':'nim','nimble':'nim',
    'crystal':'crystal','cr':'crystal','factor':'factor','forth':'forth',
    'fth':'forth','f':'fortran','f90':'fortran','f95':'fortran',
    'f03':'fortran','f08':'fortran','cob':'cobol','cbl':'cobol',
    'lisp':'lisp','lsp':'lisp','cl':'opencl','el':'elisp','ss':'scheme',
    'racket':'racket','rkt':'racket','erl':'erlang','hrl':'erlang',
    'ex':'elixir','exs':'elixir','eex':'elixir','leex':'elixir',
    'heex':'elixir','ml':'ocaml','mli':'ocaml','fsi':'fsharp','fsx':'fsharp',
    'ada':'ada','adb':'ada','vhdl':'vhdl','vhd':'vhdl','sv':'systemverilog',
    'svh':'systemverilog','verilog':'verilog','v':'verilog',
    'systemverilog':'systemverilog','tcl':'tcl','tk':'tcl','awk':'awk',
    'make':'makefile','mk':'makefile','mak':'makefile','cmake':'cmake',
    'gradle':'groovy','groovybuild':'groovy','ant':'xml','bazel':'python',
    'bzl':'python','dockerfile':'dockerfile','containerfile':'dockerfile',
    'vagrantfile':'ruby','terraform':'hcl','tf':'hcl','tfvars':'hcl',
    'hcl':'hcl','cue':'cue','rego':'rego','proto':'protobuf',
    'thrift':'thrift','avdl':'json','gql':'graphql','graphql':'graphql',
    'gqls':'graphql','psql':'pgsql','mysql':'sql','pgsql':'pgsql',
    'plsql':'plsql','tsql':'tsql','cypher':'cypher','sparql':'sparql',
    'pig':'pig','hive':'sql','presto':'sql','kql':'kql','dax':'dax',
    'stata':'stata','sas':'sas','do':'stata','ado':'stata','matlab':'matlab',
    'octave':'matlab','scilab':'scilab','sci':'scilab','wolfram':'wolfram',
    'nb':'wolfram','wl':'wolfram','gnuplot':'gnuplot','plt':'gnuplot',
    'plot':'gnuplot','shader':'glsl','glsl':'glsl','frag':'glsl',
    'vert':'glsl','geom':'glsl','comp':'glsl','metal':'metal','msl':'metal',
    'hlsl':'hlsl','cg':'hlsl','fx':'hlsl','opencl':'opencl','cuda':'cuda',
    'cu':'cuda','cuh':'cuda','zigmod':'zig','zigbuild':'zig','qml':'qml',
    'qs':'javascript','slint':'slint','ui':'xml','pascal':'pascal',
    'delphi':'pascal','dpr':'pascal','dfm':'pascal','lfm':'pascal',
    'pde':'java','ino':'cpp','gd':'gdscript','gdscript':'gdscript',
    'tscn':'gdscript','tres':'gdscript','shaderlab':'shaderlab',
    'as':'actionscript','asc':'actionscript','hx':'haxe','hxml':'xml',
    'idl':'idl','midl':'idl','webidl':'webidl','openapi':'yaml',
    'swagger':'yaml','raml':'yaml','apib':'apib','plantuml':'plantuml',
    'puml':'plantuml','mermaid':'mermaid','mmd':'mermaid','gv':'dot',
    'graphviz':'dot','smali':'smali','dalvik':'smali','gradlekts':'kotlin',
    'editorconfig':'editorconfig','gitignore':'gitignore',
    'gitattributes':'gitattributes','gitmodules':'ini','gitconfig':'ini',
    'diff':'diff','rej':'diff','orig':'diff','autoconf':'m4',
    'automake':'makefile','aclocal':'m4','m4':'m4','meson':'meson',
    'ninja':'ninja','gn':'gn','gni':'gn','scons':'python','jam':'jam',
    'jamfile':'jam','jamrules':'jam','antbuild':'xml','antxml':'xml',
    'vcxproj':'xml','vcproj':'xml','csproj':'xml','fsproj':'xml',
    'vbproj':'xml','props':'xml','targets':'xml','npmrc':'ini',
    'yarnrc':'ini','babelrc':'json','babelconfig':'javascript',
    'tsconfig':'json','jsconfig':'json','actionyaml':'yaml',
    'actionyml':'yaml','jenkinsfile':'groovy','droneyaml':'yaml',
    'gitlabyaml':'yaml','circleyaml':'yaml','travisyml':'yaml',
    'kubernetes':'yaml','kubeconfig':'yaml','k8s':'yaml',
    'apacheconf':'apacheconf','caddyfile':'caddyfile',
    'postgresconf':'pgsql','mysqlconf':'sql','yara':'yara',
    'yararule':'yara','sigma':'yaml','sigmarule':'yaml','r2':'r2',
    'idc':'c','pytest':'python','nose':'python','behave':'python',
    'cucumber':'gherkin','robot':'robotframework','lcov':'lcov','gcov':'gcov',
}
BINARY_EXTS = {
    'png','jpg','jpeg','gif','bmp','ico','webp','tiff','tif','raw',
    'psd','ai','sketch','fig','heic','heif','avif','cr2','nef','arw',
    'mp3','wav','ogg','flac','aac','m4a','wma','opus','aiff','au',
    'mp4','avi','mov','mkv','wmv','flv','webm','m4v','mpeg','mpg',
    '3gp','mts','m2ts',
    'pdf','doc','docx','xls','xlsx','ppt','pptx','odt','ods','odp',
    'pages','numbers',
    'zip','tar','gz','bz2','7z','rar','xz','lz4','zst','br','lzma',
    'cab','iso','dmg','img','deb','rpm','pkg','msi','appimage',
    'exe','dll','so','dylib','bin','dat','class','pyc','pyo','pyd',
    'o','a','lib','wasm','apk','ipa','jar','war','ear',
    'ttf','otf','woff','woff2','eot',
    'db','sqlite','sqlite3','mdb','accdb',
    'pkl','pickle','npy','npz','h5','hdf5',
    'svgz','swf','blend','fbx','stl','ply','3ds','xcf',
}
def is_binary_content(fpath, sample=8192):
    try:
        with open(fpath, 'rb') as f: return b'\x00' in f.read(sample)
    except: return True
def is_binary(fpath):
    ext = os.path.splitext(fpath)[1].lstrip('.').lower()
    return ext in BINARY_EXTS or is_binary_content(fpath)
def get_identifier(fpath):
    name = os.path.basename(fpath)
    ext  = os.path.splitext(name)[1].lstrip('.').lower()
    if not ext: ext = name.lower()
    return EXT_MAP.get(ext, 'Noidentifier')
print("")
print("# Contents:")
print("")
LARGE_FILE_THRESHOLD = 768 * 1024
files_sorted  = sorted(files_out)
binary_files  = [f for f in files_sorted if is_binary(os.path.join(base, f))]
text_files    = [f for f in files_sorted if not is_binary(os.path.join(base, f))]
files_ordered = binary_files + text_files
for i, f in enumerate(files_ordered):
    tag   = get_tag(i)
    ident = get_identifier(f)
    fpath = os.path.join(base, f)
    is_last = (i == len(files_ordered) - 1)
    if is_binary(fpath):
        file_url = upload_binary(fpath, f)
        print('# "' + f + '"')
        print('# ```' + ident)
        print("cat <<'" + tag + "' > /dev/null")
        if file_url:
            print("[binary file - not displayed")
            print("Access file using API endpoint or original source link " + file_url + "]")
        else:
            print("[binary file - not displayed]")
        print(tag)
        if not is_last: print("")
    else:
        size = 0
        try: size = os.path.getsize(fpath)
        except: pass
        print('# ```' + ident)
        if size > LARGE_FILE_THRESHOLD:
            print('# [file too large - compressed gzip+base64 - ' + str(size) + ' bytes]')
            print("cat <<'" + tag + "' | base64 -d | gzip -d > \"" + f + '"')
            try:
                with open(fpath, 'rb') as fh: raw = fh.read()
                compressed = gzip.compress(raw)
                encoded    = base64.b64encode(compressed).decode('ascii')
                for j in range(0, len(encoded), 76): print(encoded[j:j+76])
            except: pass
        else:
            print("cat <<'" + tag + "' > \"" + f + '"')
            try:
                with open(fpath, 'r', errors='replace') as fh: content = fh.read()
                if content and not content.endswith('\n'): content += '\n'
                print(content, end='')
            except: pass
        print(tag)
        if not is_last: print("")
PYEOF
    else
        _dprune=""; _fprune=""
        while IFS= read -r _d; do
            [ -n "$_d" ] && _dprune="$_dprune -not -path '*/$_d/*' -not -name '$_d'"
        done < "$_TMPD"
        while IFS= read -r _f; do
            [ -n "$_f" ] && _fprune="$_fprune -not -name '$_f'"
        done < "$_TMPF"
        printf '\n# folder create:\n'
        eval "find '$_bscan' -mindepth 1 -type d $_dprune" 2>/dev/null \
            | sed "s|^${_bscan}/||" | sort \
            | while IFS= read -r _p; do printf 'mkdir -p "%s"\n' "$_p"; done
        printf '\n# file create:\n'
        printf 'touch ".nomedia"\n'
        eval "find '$_bscan' -mindepth 1 -type d $_dprune" 2>/dev/null \
            | sed "s|^${_bscan}/||" | sort \
            | while IFS= read -r _p; do printf 'touch "%s/.nomedia"\n' "$_p"; done
        eval "find '$_bscan' -type f $_dprune $_fprune" 2>/dev/null \
            | sed "s|^${_bscan}/||" | sort \
            | while IFS= read -r _p; do printf 'touch "%s"\n' "$_p"; done
        printf '\n# Contents:\n'
        printf '# (python3 tidak tersedia - isi file tidak ditampilkan)\n'
    fi
}
_mode_tree() {
    _raw="$(_resolve_dir "${1:-}")"
    _scan="$(cd "$_raw" 2>/dev/null && pwd)" || {
        echo ""; echo "Error: Direktori '$_raw' tidak ditemukan."; echo ""; _exit 1
    }
    printf "Do you want to continue? [Y/n] "; read -r _confirm
    case "$_confirm" in
        Y|y|YA|Ya|ya|YES|Yes|yes) ;;
        *) echo ""; cecho "$C_YEL" "Dibatalkan."; echo ""; _exit 0 ;;
    esac
    _init_tmp
    if _has_binary_files "$_scan"; then
        _init_session
    fi
    _date="$(date '+%Y-%m-%d')"; _time="$(date '+%H-%M-%S')"
    _tdsp="$(date '+%H:%M:%S')"; _out="${_scan}/tree.Read_${_date}_${_time}.txt"
    _SEP="==================================================="; _sep="---------------------------------------------------"
    echo ""; echo "$_SEP"; echo "           [tree]  tree.Read.sh"; echo "$_SEP"
    echo " Path  : $_scan"; echo " Date  : $_date"; echo " Time  : $_tdsp"
    if [ -n "$_PASSWORD" ]; then printf " Pass  : "; cecho "$C_GRN" "$_PASSWORD"; fi
    echo "$_sep"; echo ""
    _output="$(_run_tree "$_scan")"
    echo "$_output"; echo ""
    {
        printf "cat <<'EOF' > /dev/null\n"
        echo "Path: $_scan"; echo "Date scan: $_date"; echo "Time scan: $_time"
        if [ -n "$_PASSWORD" ]; then
            echo "Password Access: $_PASSWORD"
            printf "Note: File ini akan otomatis 🅚🅐🅓🅐🅛🅤🅐🅡🅢🅐 𝟭 𝙢𝙞𝙣𝙜𝙜𝙪 setelah diunggah. ɴᴀᴍᴜɴ, jika file 🅳🅸🅰🅚🆂🅴🆂 ​ 🅻🅰🅶🅸 sebelum kadaluarsa, masa aktifnya akan otomatis ᴅɪᴘᴇʀᴘᴀɴᴊᴀɴɢ 𝟭 𝙢𝙞𝙣𝙜𝙜𝙪 ᵏᵉ ᵈᵉᵖᵃⁿ.\n"
        fi
        echo "content scan:"; echo "$_output"; printf "EOF\n"
        _build_create_cmds "$_scan"
    } > "$_out"
    echo "$_sep"; echo "Tersimpan -> $_out"; echo ""
}
_main() {
    case "${1:-}" in
        m:find) shift; _mode_find "$@" ;;
        *)      _mode_tree "$@" ;;
    esac
}
_main "$@"

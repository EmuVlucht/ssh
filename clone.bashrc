mkdir -p ~/device
cd ~/device

device() {
  # TERMUX
  if [ -d "/data/data/com.termux" ]; then
   echo "TERMUX"
   return
  fi

  # GOOGLE CLOUD SHELL
  if [ -n "$CLOUD_SHELL" ]; then
    echo "GCLOUD_CLOUD_SHELL"
    return
  fi

  # RAILWAY
  if [ -n "$RAILWAY_ENVIRONMENT" ] || \
     [ -n "$RAILWAY_PROJECT_ID" ] || \
     [ -n "$RAILWAY_STATIC_URL" ]; then
    echo "RAILWAY"
    return
  fi

  # DOCKER (generic container)
  if grep -qaE 'docker|kubepods|containerd' /proc/1/cgroup 2>/dev/null; then
    echo "DOCKER_CONTAINER"
    return
  fi

  # VPS / SSH
  if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ]; then
    echo "VPS_SSH"
    return
  fi

  # LOCAL
  echo "LOCAL_MACHINE"
}

clear() {
  history -c
  history -w
  rm -f ~/.bash_history
  rm -f ~/.zsh_history

  rm -rf ~/.cache
  rm -rf $PREFIX/var/log
  rm -rf $PREFIX/tmp/*

  $PREFIX/bin/clear
}

# ===== GCS CORE FUNCTION =====
_gcs_connect() {
  local mode="$1"
  local path="$2"

  if [ "$mode" = "0" ]; then
    gcloud cloud-shell ssh --authorize-session
  else
    while true; do
      echo "Menghubungkan ke Cloud Shell..."

      gcloud cloud-shell ssh \
        --authorize-session \
        --ssh-flag="-o ServerAliveInterval=60" \
        --ssh-flag="-o ServerAliveCountMax=3" \
        --command "echo \"START: \$(date)\" >> /home/${path}/gcs-runtime.txt; while true; do echo \"Still alive: \$(date)\" >> /tmp/heartbeat.txt; sleep \$((RANDOM % 180 + 120)); done"

      echo "Koneksi terputus. Reconnect dalam 10 detik..."
      sleep 10
    done
  fi
}

# ===== GCS MULTI ACCOUNT =====

gcs1() {
  export CLOUDSDK_CONFIG="/root/.gcloud/.gcloud-akunku11.mb"
  gcloud config set account akunku11.mb@gmail.com >/dev/null 2>&1
  _gcs_connect "$1" "akunku11_mb"
}

gcs2() {
  export CLOUDSDK_CONFIG="/root/.gcloud/.gcloud-d.budzverse.nl"
  gcloud config set account d.budzverse.nl@gmail.com >/dev/null 2>&1
  _gcs_connect "$1" "d_budzverse_nl"
}

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/bin/google-cloud-sdk/path.bash.inc' ]; then . '/bin/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/bin/google-cloud-sdk/completion.bash.inc' ]; then . '/bin/google-cloud-sdk/completion.bash.inc'; fi

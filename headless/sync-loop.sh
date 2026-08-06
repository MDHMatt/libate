#!/bin/bash
# Headless Libation sync loop.
#
# Each cycle: scan every configured Audible account -> liberate anything new ->
# run the post-sync hook (if one is mounted at /hooks/post-sync.sh). The hook is
# where downstream integrations live (AudioBookRequest reconcile, Audiobookshelf
# scan) - kept OUTSIDE the image so the deploying stack can evolve it via GitOps
# without an image rebuild.
#
# SYNC_INTERVAL: sleep between cycles (any `sleep` duration, e.g. 6h, 30m).
#                Set to -1 to run a single cycle and exit.
set -u

INTERVAL="${SYNC_INTERVAL:-6h}"

echo "[libation-sync] starting; interval=${INTERVAL}; accounts configured: $(LibationCli export --help >/dev/null 2>&1 && echo cli-ok)"

while :; do
  # Re-stage config from the PERSISTENT volume each cycle. Upstream's entrypoint
  # only does this once at start, and it COPIES (only the DB is symlinked) - so an
  # account added later (e.g. by the login web helper, which writes straight to
  # /config via --libationFiles) would otherwise be invisible until a restart.
  for f in AccountsSettings.json Settings.json; do
    if [ -s "${LIBATION_CONFIG_DIR:-/config}/$f" ]; then
      cp -f "${LIBATION_CONFIG_DIR:-/config}/$f" "${LIBATION_CONFIG_INTERNAL:-/config-internal}/$f" 2>/dev/null || true
    fi
  done

  echo "[libation-sync] $(date -Is) scan starting (all accounts)"
  LibationCli scan || echo "[libation-sync] WARN: scan failed (rc=$?)"

  echo "[libation-sync] $(date -Is) liberate starting"
  LibationCli liberate || echo "[libation-sync] WARN: liberate failed (rc=$?)"

  if [ -x /hooks/post-sync.sh ]; then
    echo "[libation-sync] $(date -Is) running post-sync hook"
    /hooks/post-sync.sh || echo "[libation-sync] WARN: post-sync hook failed (rc=$?)"
  elif [ -f /hooks/post-sync.sh ]; then
    # Bind-mounted from a repo checkout: the file may arrive without +x.
    bash /hooks/post-sync.sh || echo "[libation-sync] WARN: post-sync hook failed (rc=$?)"
  fi

  [ "${INTERVAL}" = "-1" ] && { echo "[libation-sync] single-run mode, exiting"; break; }
  echo "[libation-sync] $(date -Is) cycle complete; sleeping ${INTERVAL}"
  sleep "${INTERVAL}"
done

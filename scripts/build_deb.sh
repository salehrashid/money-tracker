#!/usr/bin/env bash
set -euo pipefail
umask 022

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command_name in flutter dpkg-deb dpkg; do
  command -v "$command_name" >/dev/null || {
    echo "Missing required command: $command_name" >&2
    exit 1
  }
done

version="$(sed -n 's/^version: *\([^[:space:]]*\).*/\1/p' pubspec.yaml | head -n 1)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$ ]]; then
  echo "Unsupported version in pubspec.yaml: $version" >&2
  exit 1
fi
package_version="${version/+/-}"
architecture="$(dpkg --print-architecture)"
case "$architecture" in
  amd64) flutter_arch=x64 ;;
  arm64) flutter_arch=arm64 ;;
  *) echo "Unsupported architecture: $architecture" >&2; exit 1 ;;
esac

if [[ "${1:-}" == "--skip-build" ]]; then
  :
elif [[ $# -eq 0 ]]; then
  flutter build linux --release
else
  echo "Usage: $0 [--skip-build]" >&2
  exit 1
fi
bundle="build/linux/$flutter_arch/release/bundle"
[[ -x "$bundle/fleeca" && -f "$bundle/data/app_icon.png" ]] || {
  echo "Linux release bundle is incomplete: $bundle" >&2
  exit 1
}

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
install -d "$staging/DEBIAN" "$staging/opt/fleeca" \
  "$staging/usr/bin" "$staging/usr/share/applications" \
  "$staging/usr/share/icons/hicolor/512x512/apps"
cp -a "$bundle/." "$staging/opt/fleeca/"
ln -s /opt/fleeca/fleeca "$staging/usr/bin/fleeca"
install -m 644 "$bundle/data/app_icon.png" \
  "$staging/usr/share/icons/hicolor/512x512/apps/fleeca.png"

cat > "$staging/usr/share/applications/fleeca.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Fleeca
Comment=Personal finance tracker
Exec=fleeca
Icon=fleeca
Terminal=false
Categories=Office;
EOF

installed_size="$(du -sk "$staging/opt" "$staging/usr" | awk '{sum += $1} END {print sum}')"
cat > "$staging/DEBIAN/control" <<EOF
Package: fleeca
Version: $package_version
Section: utils
Priority: optional
Architecture: $architecture
Depends: libgtk-3-0, libsecret-1-0
Maintainer: Fleeca
Installed-Size: $installed_size
Description: Private personal finance tracker
 Fleeca tracks accounts, transactions, categories, debts, receivables,
 dashboard summaries, statistics, and CSV imports.
EOF

output="build/linux/fleeca_${package_version}_${architecture}.deb"
dpkg-deb --build --root-owner-group "$staging" "$output"
echo "Created $output"

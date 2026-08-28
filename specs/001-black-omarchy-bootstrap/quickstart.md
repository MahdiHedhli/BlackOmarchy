# Quickstart (operator)

v0.1 install is clone, read, then run. There is no remote root pipe.

On the Omarchy host:

```bash
git clone https://github.com/MahdiHedhli/BlackOmarchy.git
cd BlackOmarchy
less bootstrap.sh
sudo ./bootstrap.sh
blackomarchy status
blackomarchy verify
```

Optional profiles:

```bash
blackomarchy profiles
sudo blackomarchy install web
```

Remove the layer:

```bash
sudo ./uninstall.sh
```

Keep using `omarchy update` for Omarchy. Do not replace it with
`pacman -Syu`.

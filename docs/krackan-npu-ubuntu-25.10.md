# Getting the Ryzen AI NPU (Krackan Point) alive on Ubuntu 25.10

Hardware: AMD Ryzen AI 5 340, Krackan Point, PCI `1022:17f0`, BDF `0000:05:00.1`.
OS: Ubuntu 25.10 (fresh install, April 2026).
Goal: run ONNX models on the NPU via AMD RyzenAI SDK 1.7.1.

## The wall

Stock Ubuntu 25.10 kernel (`6.17.0-22-generic`) loads `amdxdna` fine, but any
`open("/dev/accel/accel0", O_RDWR)` fails instantly with:

```
amdxdna 0000:05:00.1: [drm] *ERROR* amdxdna_drm_open: SVA bind device failed, ret -95
```

`-95` is `EOPNOTSUPP` returned from `iommu_sva_bind_device()`. It happens even
when:

- IOMMU is enabled in BIOS,
- AMD-Vi reports `EFR=0x246577efa2254afa` with the `PCSup` bit set,
- `IOMMU_SVA`, `IOMMU_IOPF`, `AMD_IOMMU`, `PCI_PASID` are all `=y`,
- No `amd_iommu=` / `iommu=` overrides on cmdline.

## The cause

This is a known IOMMU-SVA regression backported to the 6.17 / 6.18.y stable
trees. Confirmed by Mario Limonciello (AMD, `@superm1`) in
[xdna-driver#1028](https://github.com/amd/xdna-driver/issues/1028):

> This was a regression in the IOMMU subsystem specifically to 6.18.y.
> 6.19-rc is not affected. It will be fixed in an upcoming 6.18.y kernel.

Ubuntu's 6.17.0-22-generic carries the same buggy backport.

## The fix

Boot a mainline kernel ≥ 6.19:

```bash
# Ubuntu mainline PPA style — grab the latest 6.19.x build from
# https://kernel.ubuntu.com/mainline/
# e.g. 6.19.13-061913-generic
sudo dpkg -i linux-headers-6.19.13-*.deb linux-image-unsigned-6.19.13-*.deb \
             linux-modules-6.19.13-*.deb
sudo update-grub
reboot
```

Verify after reboot:

```bash
uname -r
# 6.19.13-061913-generic

dmesg | grep -i amdxdna
# [    3.249434] amdxdna 0000:05:00.1: PASID address mode enabled
# [    3.391144] [drm] Initialized amdxdna_accel_driver 1.0.0 for 0000:05:00.1

ls /dev/accel/accel0
# /dev/accel/accel0
```

## Second wall: xrt-smi EAGAIN

```
[xrt-smi] ERROR: mmap(... len=67108864 ...) failed (err=-11): Resource temporarily unavailable
```

`RLIMIT_MEMLOCK` defaults to 8 MiB; XRT wants ≥ 64 MiB pinned. Fix:

```bash
sudo tee /etc/security/limits.d/30-xrt-memlock.conf <<EOF
* soft memlock unlimited
* hard memlock unlimited
EOF
# log out / reboot for the limit to take effect
ulimit -l   # -> unlimited
```

Then:

```bash
source /opt/xilinx/xrt/setup.sh
xrt-smi examine
```

Expected:

```
NPU Firmware Version : 1.1.2.64
|[0000:05:00.1]  |NPU Krackan 1  |aie2p  |6x8  |
```

## Third wall: RyzenAI SDK installer

SDK tarball: `ryzen_ai-1.7.1.tgz` (~11 GB, from the AMD download portal).
Install script hard-requires Python 3.12; 25.10 ships 3.13.

Cleanest fix (no deadsnakes PPA, no system python touching):

```bash
uv python install 3.12
ln -sf "$(uv python find 3.12)" ~/.local/bin/python3.12
```

Then the installer fails at `python -m venv --copies` because uv's managed
cpython doesn't bundle ensurepip the same way. Drop the flag:

```bash
sed -i 's/python3.12 -m venv "${path_to_venv}" --copies/python3.12 -m venv "${path_to_venv}"/' \
    install_ryzen_ai.sh
```

Also: **do not install the 4 XRT debs that ship with RAI 1.7.1** — they're
2.21.75, but Ubuntu 25.10 already has 2.23.0, which is newer and works. Let
the installer downgrade-warning you about that and skip.

Run:

```bash
bash install_ryzen_ai.sh -a yes -p ~/ryzen_ai_venv -c ~/ryzen_ai_cpp
```

## Smoke test

The `quicktest.py` hard-codes its model path under the venv root; symlink it:

```bash
ln -s ~/ryzen_ai_cpp/quicktest ~/ryzen_ai_venv/quicktest
```

Then:

```bash
source /opt/xilinx/xrt/setup.sh
source ~/ryzen_ai_venv/bin/activate
cd ~/ryzen_ai_cpp/quicktest
python quicktest.py
# -> Setting environment for STX/KRK
# -> Test Finished
```

Full stack alive: kernel → amdxdna → XRT → VitisAIExecutionProvider → ONNX.

## Config snapshot that worked

| Component | Version |
|---|---|
| Distro | Ubuntu 25.10 |
| Kernel | 6.19.13-061913-generic (mainline) |
| amdxdna | OOT 1.0.0 / plugin 2.23.0_20260419 |
| XRT | 2.23.0 |
| NPU firmware | 1.1.2.64 |
| RyzenAI SDK | 1.7.1 |
| Python | 3.12.13 (uv-managed) |
| ONNX Runtime | 1.23.3.dev20260320 (vitisai build) |

## References

- [amd/xdna-driver#1028](https://github.com/amd/xdna-driver/issues/1028) — the SVA bind regression
- [amd/xdna-driver#704](https://github.com/amd/xdna-driver/issues/704) — same error string, different cause (IOMMU disabled → ret -19)
- Ubuntu mainline kernels: https://kernel.ubuntu.com/mainline/

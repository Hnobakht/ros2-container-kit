# ROS 2 Jazzy + Gazebo Harmonic Docker development kit

**Now with optional robotics research stacks:** mobile navigation and SLAM,
CUDA ML/RL, Universal Robots + MoveIt manipulation, and Open-RMF warehouse /
factory demonstrations. See [Stack guide](docs/STACKS.md) and
[Offline/preload guide](docs/OFFLINE.md). Original `docker compose up -d ros`
continues to work.

To preload the curated images, reference source trees, 3D assets and compact
model weights while Internet access is available:

```bash
bash scripts/prepare.sh
bash scripts/preload.sh --all
```

This is intentionally **not** a single monolithic image: PyTorch, manipulation,
and fleet simulation have different dependencies, and heavyweight GPU tools
must not be imposed on a 6 GB RTX 2060. Downloaded binary assets remain
outside Git. Run `bash scripts/preload.sh --help` for selective options.

For Ubuntu 26.04 hosts, running ROS 2 Jazzy inside an Ubuntu 24.04-based
container keeps ROS, colcon, rosdep, Gazebo, and their Python libraries off the
host OS. The source workspace is bind-mounted, so it persists outside Docker.

## Files

- `Dockerfile.ros`: ROS Jazzy desktop, Gazebo Harmonic integration, RViz2,
  colcon, rosdep, developer tools, and non-root development user.
- `compose.yaml`: GPU-accelerated ROS development container with an X11/XWayland
  GUI, host networking, and persistent workspace.
- `compose.isaac.yaml`: **optional** official Isaac Sim 6.2 image. Disabled by
  default; it is **not suitable for an RTX 2060 6 GB**.
- `.devcontainer/devcontainer.json`: VS Code "Reopen in Container" support.
- `scripts/prepare.sh`: creates user-specific `.env` and private X11 cookie
  inside this project. Does not install anything on your OS.

## Host prerequisites

1. Ubuntu Linux with a working NVIDIA driver (`nvidia-smi`).
2. Docker Engine and Docker Compose v2 (`docker compose version`).
3. NVIDIA Container Toolkit, configured for Docker; confirm GPU passthrough:

   ```bash
   docker run --rm --gpus all ubuntu:24.04 nvidia-smi
   ```

4. An X11 or XWayland session (`echo "$DISPLAY"`) and the small host `xauth`
   utility (`command -v xauth`). GNOME Wayland generally provides XWayland,
   but this specific GUI-forwarding setup needs a working X display.
5. VS Code + the Dev Containers extension (optional).

Official install instructions:

- Docker: https://docs.docker.com/engine/install/ubuntu/
- NVIDIA Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
- ROS/Gazebo compatibility: https://gazebosim.org/docs/jetty/ros_installation/

**Important:** Do not use `sudo pip`, install ROS packages on the host, or
modify `/usr/bin/python3`. Docker/Toolkit installation does change the host
container runtime configuration, but ROS itself stays in the image.

## First run

In a terminal **inside the graphical desktop session**, from this directory:

```bash
bash scripts/prepare.sh
docker compose config --quiet
docker compose build ros
docker compose up -d ros
docker compose exec ros bash
```

The script copies your X11 cookie to `.docker/Xauthority` with private file
permissions; it does not execute `xhost +local:` or relax display access for
every local process. Run it again if your desktop login/session changes.

Inside the container:

```bash
ros2 --help
colcon --help
gz sim -v 4 shapes.sdf
```

Gazebo should open on the Ubuntu desktop. Stop it with Ctrl+C.
To test RViz2, run `rviz2` in the container in a separate terminal.

For ROS builds:

```bash
cd /workspace/ros2_ws
# Add or clone ROS packages into src/ (also visible on your host).
colcon build --symlink-install
source install/setup.bash
```

If the build fails on `gz: command not found`, check package installation:
`dpkg -l | grep -E 'ros-jazzy-ros-gz|gz-sim'` inside the container.

## VS Code workflow

1. First run `bash scripts/prepare.sh` on the host.
2. Open the **root of this kit** in VS Code (the folder containing compose.yaml).
3. Run **Dev Containers: Reopen in Container**.
4. Your editor opens `/workspace/ros2_ws` within the development container.

Extensions run in the development container. Your host's Python stays unchanged.

## Day-to-day operations

From the kit's root directory on the host:

```bash
docker compose up -d ros        # start existing development container
docker compose exec ros bash    # open another ROS terminal
docker compose down             # stop/remove service container, not workspace
docker compose build ros        # rebuild after Dockerfile changes
```

`docker compose down` **without** `-v` preserves the named cache volume.
Never run `docker compose down -v` if you want to keep those caches.

The ROS workspace is in `ros2_ws/` on the host. This kit does not remove or
overwrite any pre-existing ROS installation or prior workspace on your machine.
Copy your packages into this kit's `ros2_ws/src/` yourself, or edit the bind
mount in `compose.yaml` to point to your existing workspace. Do not mount your
entire home directory into the container.

## Isaac Sim (future supported GPU / remote workstation)

NVIDIA Isaac Sim 6.2 requires at least an RTX 4080-class GPU, 16 GB VRAM, and
32 GB RAM. Your RTX 2060 6 GB does not meet these requirements. This optional
service is **off by default** and should not be launched on your current GPU.

On a **supported** machine, after reviewing and agreeing to NVIDIA's EULA,
and only if you choose to supply consent for the relevant variables:

```bash
ACCEPT_EULA=Y PRIVACY_CONSENT=Y \
  docker compose -f compose.yaml -f compose.isaac.yaml \
  --profile isaac up -d isaac
```

This uses the official image in headless streaming mode, with shared ROS domain
and host network. Connect using NVIDIA's WebRTC streaming client; this kit does
not bundle a web viewer. Isaac may require additional DDS profile configuration
when exchanging messages with external ROS nodes. See the official Isaac docs:

- https://docs.isaacsim.omniverse.nvidia.com/6.2.0/installation/install_container.html
- https://docs.isaacsim.omniverse.nvidia.com/6.2.0/installation/install_ros.html

Stop the optional service with:

```bash
docker compose -f compose.yaml -f compose.isaac.yaml --profile isaac down
```

## Troubleshooting

- `Cannot open display`: Run `bash scripts/prepare.sh` again **in the logged-in
  GUI terminal**, check `echo "$DISPLAY"`, restart the ROS container, and
  confirm XWayland is working if you use a Wayland desktop.
- `nvidia-smi` unavailable inside container: Fix host NVIDIA driver / NVIDIA
  Container Toolkit before building ROS. Docker cannot supply a missing host
  driver.
- Gazebo GUI blank/slow: Check `glxinfo -B` **inside the container**;
  software rendering is much slower. Hybrid-GPU laptops may need additional
  graphics offloading settings specific to the desktop.
- Packages can't communicate: They must share `ROS_DOMAIN_ID` and compatible
  DDS/RMW settings. `network_mode: host` makes ROS multicast easier but removes
  Docker's network isolation for this service.
- Permission errors in workspace: Rebuild with UID/GID from
  `bash scripts/prepare.sh`; avoid running `colcon` as root.
- `apt install` inside the non-root container: Prefer editing `Dockerfile.ros`
  and rebuilding. For temporary debugging, `docker compose exec -u root ros bash`
  opens an isolated root shell **inside the container**, not on the host.

## Security notes

- Use only images/Dockerfiles you trust: Docker access is powerful.
- The X11 cookie grants the container access to the user's graphical session.
- Host networking gives the ROS container access to the host network stack.
- No `privileged: true`, `/var/run/docker.sock`, or host home directory mounts
  are included.

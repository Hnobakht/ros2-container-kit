# Robotics development stacks

All images use **Ubuntu 24.04 + ROS 2 Jazzy + Gazebo Harmonic** internally,
regardless of whether your host is Ubuntu 26.04. They share ROS DDS host
networking and GUI/GPU settings from `compose.yaml`.

Run `bash scripts/prepare.sh` in your graphical desktop terminal first.
Run `docker compose build ros` before building optional images.

| Stack | Image | Best for | Principal tools |
|---|---|---|---|
| `ros` | `local/ros2-jazzy-gazebo:dev` | Mobile robots, JetBot-like robots, perception | Nav2, SLAM Toolbox, robot_localization, ros2_control, Gazebo, RViz, MCAP |
| `ml` | `local/ros2-jazzy-ml:dev` | AI, ML, RL, robot learning | PyTorch CUDA 12.6, SB3, Gymnasium, PettingZoo, MuJoCo, Jupyter, Hugging Face |
| `manipulation` | `local/ros2-jazzy-manipulation:dev` | Industrial arms | MoveIt 2, Universal Robots ROS 2 driver, UR/Gazebo simulation |
| `warehouse` | `local/ros2-jazzy-warehouse:dev` | Fleet logistics/digital twins | Open-RMF demos, Gazebo worlds, MCAP |

## Build and launch

```bash
docker compose build ros
docker compose -f compose.yaml -f compose.stacks.yaml build ml manipulation warehouse
```

Start **one** stack at a time if you want to control a single simulation:

```bash
docker compose -f compose.yaml -f compose.stacks.yaml --profile ml up -d ml
docker compose -f compose.yaml -f compose.stacks.yaml --profile ml exec ml bash
```

Substitute `manipulation` or `warehouse` for `ml` above. Stop with:

```bash
docker compose -f compose.yaml -f compose.stacks.yaml --profile ml down
```

The base `ros` service works with the original commands and Dev Container.
The optional stacks inherit that service's X11/XWayland and NVIDIA GPU settings.

With a service already running, perform non-GUI checks from the host:

```bash
bash scripts/smoke-test.sh ros
bash scripts/smoke-test.sh ml  # when the ML service is running
```

## Mobile robots / JetBot / navigation

```bash
docker compose up -d ros
docker compose exec ros bash
ros2 launch nav2_bringup tb3_simulation_launch.py headless:=False
```

Nav2's modern Jazzy instructions are at https://docs.nav2.org/jazzy/ .
For a custom two-wheel or four-wheel robot, create a package under
`ros2_ws/src/` with a URDF/Xacro, `ros2_control`, sensor descriptions and
`ros_gz` bridges. The environment includes the standard ROS primitives,
not a prebuilt JetBot-specific Jazzy driver.

**JetBot hardware matters:** Original NVIDIA JetBot used the Jetson Nano and
JetPack 4.x. Do not run this x86_64 ROS Jazzy image directly on a Nano and
assume GPIO/motors/camera will work. Keep the host PC for development,
simulation, perception and training; deploy to an appropriate Jetson-specific
ARM64 image compatible with its JetPack release. NVIDIA now points new
builds toward Jetson Orin Nano. See https://jetbot.org/ .

## Universal Robots manipulation

```bash
docker compose -f compose.yaml -f compose.stacks.yaml --profile manipulation up -d manipulation
docker compose -f compose.yaml -f compose.stacks.yaml --profile manipulation exec manipulation bash
ros2 pkg list | grep '^ur_'
ros2 pkg list | grep moveit
```

For UR5e/UR10e simulation, use `ur_simulation_gz` and the launch files
installed by the distribution; inspect them via
`ros2 pkg prefix ur_simulation_gz` because upstream launch names can change.

For URSim controller emulation, Universal Robots provides its own simulator and
instructions: https://docs.universal-robots.com/Universal_Robots_ROS_Documentation/jazzy/doc/ur_robot_driver/ur_robot_driver/doc/usage/simulation.html .
That simulator is separate from Gazebo and should be obtained under its own
license/terms.

**Real-arm safety:** This Docker kit is a development setup, not a certified
industrial controller. Validate collision boundaries, emergency stops,
calibration, and real-time networking independently before operating hardware.
UR recommends a low-latency/PREEMPT_RT kernel for strict control cycles;
Docker does not eliminate host kernel requirements.

## AI, ML and reinforcement learning

```bash
docker compose -f compose.yaml -f compose.stacks.yaml --profile ml up -d ml
docker compose -f compose.yaml -f compose.stacks.yaml --profile ml exec ml bash
python -c 'import torch; print(torch.__version__, torch.cuda.is_available())'
python -c 'import rclpy, gymnasium, stable_baselines3; print("ready")'
```

Python packages are installed in `/opt/venvs/robotics-ml` (Python 3.12,
system ROS packages exposed read-only through `--system-site-packages`).
The host Python is not modified. The wheel build uses PyTorch 2.8.0 cu126;
check the host NVIDIA driver compatibility before assuming CUDA is available.
Large vision models and training batches can exceed an RTX 2060's 6 GB VRAM.

There is a shared `ml_cache` volume for PyTorch and Hugging Face weights and
a host-mounted `downloads/datasets` directory for your own datasets.
Use Jupyter with a local-only bind and the token it prints; host networking
does not isolate arbitrary ports automatically.

## Warehouse and factory digital twins

```bash
docker compose -f compose.yaml -f compose.stacks.yaml --profile warehouse up -d warehouse
docker compose -f compose.yaml -f compose.stacks.yaml --profile warehouse exec warehouse bash
ros2 pkg prefix rmf_demos_gz
ros2 launch rmf_demos_gz office.launch.xml
```

Open-RMF demos include hotel, office, airport, clinic, campus and
manufacturing/logistics examples. Some worlds can require extra assets or
additional services. First test with the GUI on your existing NVIDIA setup.
See https://github.com/open-rmf/rmf_demos .

Assets downloaded by `scripts/preload.sh --sources` are mounted read-only
under `/workspace/assets`. These legacy Gazebo-model assets may need
converting or adjusting for modern Gazebo Harmonic; they are a model library,
not a guaranteed ready-made factory digital twin.

## Separate build artifacts

Each optional stack mounts distinct named volumes for `build/`,
`install/`, and `log/` inside the same host source workspace. This avoids
cross-compiling build artifacts against different image dependencies. Sources
remain editable on the host. Use `docker compose down` without `-v` to
preserve caches and build results.

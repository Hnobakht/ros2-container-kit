#!/usr/bin/env bash
# Optional, large downloads to run while Internet access is available.
# All output stays in local Docker images/volumes or ./downloads (Git-ignored).
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_dir}"

usage() {
  printf '%s\n' \
    'Usage: bash scripts/preload.sh [--all | --images | --sources | --models]' \
    '                               [--extended-models] [--isaac-image]' \
    '  --all              Build ROS, ML, manipulation, warehouse; cache sources/models.' \
    '  --images           Build all local development images only.' \
    '  --sources          Download upstream source references and legacy Gazebo models.' \
    '  --models           Download compact vision, depth and language models.' \
    '  --extended-models  Include larger model weights (implies --models).' \
    '  --isaac-image      Pull Isaac Sim 6.2 image (RTX 2060 6 GB cannot run it).' \
    'Requires Docker Engine, NVIDIA Toolkit, the graphical-session prepare.sh,' \
    'and sufficient free disk space. Does not install host ROS/Python packages.'
}

if (( $# == 0 )); then
  usage
  exit 0
fi

do_images=false
do_sources=false
do_models=false
extended=false
isaac=false

for arg in "$@"; do
  case "${arg}" in
    --all) do_images=true; do_sources=true; do_models=true ;;
    --images) do_images=true ;;
    --sources) do_sources=true ;;
    --models) do_models=true ;;
    --extended-models) do_models=true; extended=true ;;
    --isaac-image) isaac=true ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "${arg}" >&2; usage; exit 2 ;;
  esac
done

mkdir -p downloads/{sources,assets,datasets}

compose=(docker compose -f compose.yaml -f compose.stacks.yaml)

if "${do_images}"; then
  "${compose[@]}" build ros
  for service in manipulation warehouse ml; do
    "${compose[@]}" build "${service}"
  done
fi

clone_reference() {
  local name="$1" url="$2" ref="$3"
  local dest="downloads/sources/${name}"
  if [[ -d "${dest}/.git" ]]; then
    printf 'Already cached: %s (not modifying local changes)\n' "${name}"
    return
  fi
  if [[ -n "${ref}" ]]; then
    git clone --depth 1 --branch "${ref}" "${url}" "${dest}"
  else
    git clone --depth 1 "${url}" "${dest}"
  fi
}

if "${do_sources}"; then
  clone_reference navigation2 https://github.com/ros-navigation/navigation2.git jazzy
  clone_reference slam_toolbox https://github.com/SteveMacenski/slam_toolbox.git jazzy
  clone_reference ros2_control https://github.com/ros-controls/ros2_control.git jazzy
  clone_reference ros_gz https://github.com/gazebosim/ros_gz.git jazzy
  clone_reference moveit2 https://github.com/moveit/moveit2.git jazzy
  clone_reference universal_robots_ros2_driver \
    https://github.com/UniversalRobots/Universal_Robots_ROS2_Driver.git jazzy
  clone_reference rmf_demos https://github.com/open-rmf/rmf_demos.git jazzy
  clone_reference universal_robots_gz_simulation \
    https://github.com/UniversalRobots/Universal_Robots_ROS2_GZ_Simulation.git ros2
  clone_reference jetbot https://github.com/NVIDIA-AI-IOT/jetbot.git ''
  clone_reference isaacsim_ros_workspaces \
    https://github.com/isaac-sim/IsaacSim-ros_workspaces.git IsaacSim-6.2.0

  if [[ ! -d downloads/assets/gazebo_models/.git ]]; then
    git clone --depth 1 https://github.com/osrf/gazebo_models.git \
      downloads/assets/gazebo_models
  fi
fi

if "${do_models}"; then
  if ! docker image inspect local/ros2-jazzy-ml:dev >/dev/null 2>&1; then
    printf 'ML image missing. Run bash scripts/preload.sh --images first.\n' >&2
    exit 1
  fi
  preset=compact
  if "${extended}"; then preset=extended; fi
  "${compose[@]}" --profile ml run --rm --no-deps -T ml \
    python /opt/robotics/preload_models.py --preset "${preset}"
fi

if "${isaac}"; then
  printf '%s\n' 'Isaac Sim needs >=16 GB VRAM and a supported GPU to run.' \
    'Downloading it does not make it compatible with an RTX 2060 6 GB.'
  docker pull nvcr.io/nvidia/isaac-sim:6.2.0
fi

printf '%s\n' 'Preload finished. Sources/assets live in ./downloads (not committed).'

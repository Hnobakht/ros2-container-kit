#!/usr/bin/env bash
# Run on the host: bash scripts/smoke-test.sh [ros|ml|manipulation|warehouse]
# Also works inside any of the kit's containers with ROS already installed.
set -euo pipefail

stack="${1:-ros}"
case "${stack}" in
  ros|ml|manipulation|warehouse) ;;
  *) printf 'Unknown stack: %s\n' "${stack}" >&2; exit 2 ;;
esac

if [[ ! -f /opt/ros/jazzy/setup.bash ]]; then
  project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  cd "${project_dir}"
  if [[ "${stack}" == ros ]]; then
    docker compose -f compose.yaml exec -T ros bash -s -- ros < scripts/smoke-test.sh
  else
    docker compose -f compose.yaml -f compose.stacks.yaml --profile "${stack}" \
      exec -T "${stack}" bash -s -- "${stack}" < scripts/smoke-test.sh
  fi
  exit
fi

source /opt/ros/jazzy/setup.bash

check_pkg() {
  local name="$1"
  ros2 pkg prefix "${name}" >/dev/null
  printf 'OK %s\n' "${name}"
}

printf 'Checking ROS 2 Jazzy, stack=%s\n' "${stack}"
check_pkg rclpy
check_pkg ros_gz_bridge
check_pkg nav2_bringup
check_pkg slam_toolbox
check_pkg controller_manager
check_pkg rosbag2_storage_mcap
gz sim --versions

case "${stack}" in
  ros) ;;
  ml)
    python -c 'import torch, gymnasium, stable_baselines3; print("PyTorch", torch.__version__, "CUDA available:", torch.cuda.is_available())'
    ;;
  manipulation)
    check_pkg moveit_ros_move_group
    check_pkg ur_robot_driver
    ;;
  warehouse)
    check_pkg rmf_demos_gz
    ;;
esac

printf 'Checks passed for %s. GUI/GPU simulation must be tested separately.\n' "${stack}"

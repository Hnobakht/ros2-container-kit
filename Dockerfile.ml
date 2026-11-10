# Build the core image first: docker compose build ros
FROM local/ros2-jazzy-gazebo:dev

USER root

# Keep pip packages out of Ubuntu's /usr Python and out of ROS apt packages.
# --system-site-packages permits importing apt-installed rclpy/cv_bridge in
# the venv without pip overwriting their Debian package installations.
ENV VIRTUAL_ENV=/opt/venvs/robotics-ml
ENV PATH="/opt/venvs/robotics-ml/bin:${PATH}"

ARG TORCH_CUDA_INDEX=https://download.pytorch.org/whl/cu126

COPY requirements/ml.txt /tmp/requirements-ml.txt
COPY scripts/preload_models.py /opt/robotics/preload_models.py

RUN python3 -m venv --system-site-packages "${VIRTUAL_ENV}" \
    && "${VIRTUAL_ENV}/bin/python" -m pip install --no-cache-dir --upgrade pip wheel \
    && "${VIRTUAL_ENV}/bin/python" -m pip install --no-cache-dir \
        torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 \
        --index-url "${TORCH_CUDA_INDEX}" \
    && "${VIRTUAL_ENV}/bin/python" -m pip install --no-cache-dir \
        -r /tmp/requirements-ml.txt \
    && mkdir -p /home/ros/.cache \
    && chown -R ros /opt/venvs /opt/robotics /home/ros/.cache

USER ros
WORKDIR /workspace/ros2_ws
CMD ["bash"]

# Use Python 3.10 as the base environment
FROM python:3.10

# Set up the working directory
WORKDIR /code

# opencv-python-headless still dynamically links against these system
# libraries at import time even without GUI support — without them, cv2
# fails to import at all (used for the face-detection sanity filter).
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy your requirements and install them
COPY ./requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

# Hugging Face requires a non-root user, so we set that up here
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR $HOME/app

# Copy the rest of your backend files into the container
COPY --chown=user . $HOME/app

# Cache the pinned public model bundle in the image during the build. This
# keeps large weights out of the Space Git history and avoids downloading them
# during the first API request.
RUN python -c "from model_artifacts import MODEL_ROOT; print(f'Model bundle cached at {MODEL_ROOT}')"

# Start the FastAPI server (Hugging Face requires port 7860)
CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "7860"]

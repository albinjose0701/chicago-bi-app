# Dockerfile for Building Permits Data Pipeline
# Runs incremental transformations from Bronze to Gold layers

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy SQL files and Python script
COPY *.sql ./
COPY run_pipeline.py ./

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PROJECT_ID=chicago-bi-app-msds-432-476520
ENV LOCATION=us-central1

# Run the pipeline
CMD ["python", "run_pipeline.py"]

# Backend - FastAPI

## Requirements
- Python 3.10+

## Setup

1. **Create & activate virtualenv:**
    ```bash
    python -m venv venv
    # On Windows:
    venv\Scripts\activate
    # On Mac/Linux:
    source venv/bin/activate
    ```
2. **Install dependencies:**
    ```bash
    pip install -r requirements.txt
    ```
3. **Copy and edit your environment file:**
    ```bash
    cp .env.example .env  # Or copy manually on Windows
    # Edit .env to set APP_NAME, ENV, DATABASE_URL, etc.
    ```
4. **Run the server:**
    ```bash
    uvicorn app.main:app --reload
    ```

- Visit [http://localhost:8000](http://localhost:8000) to see the app running.

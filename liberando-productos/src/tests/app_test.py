"""
Module used for testing simple server module
"""

from fastapi.testclient import TestClient
import pytest
from prometheus_client import REGISTRY

from application.app import app

client = TestClient(app)

class TestSimpleServer:
    """
    TestSimpleServer class for testing SimpleServer
    """
    @pytest.mark.asyncio
    async def read_health_test(self):
        """Tests the health check endpoint"""
        response = client.get("health")

        assert response.status_code == 200
        assert response.json() == {"health": "ok"}

    @pytest.mark.asyncio
    async def read_main_test(self):
        """Tests the main endpoint"""
        response = client.get("/")

        assert response.status_code == 200
        assert response.json() == {"msg": "Hello World"}

    @pytest.mark.asyncio
    async def read_bye_test(self):
        """Tests the bye endpoint"""
        before_bye_call = REGISTRY.get_sample_value('bye_requests_total')
        assert before_bye_call == 0

        response = client.get("/bye")
        after_bye_call = REGISTRY.get_sample_value('bye_requests_total')

        assert after_bye_call == 1
        assert response.status_code == 200
        assert response.json() == {"msg": "Bye bye"}


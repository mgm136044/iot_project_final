import json
import sys
import os

try:
    import requests
except ImportError:
    requests = None


def get_location_by_ip(timeout: float = 3.0):
    """
    Get approximate location (latitude, longitude) based on public IP address.

    This is used as a fallback when real GPS is not available.

    Returns:
        tuple[float, float] | None: (lat, lon) if successful, otherwise None.
    """
    if requests is None:
        print("[IPGeo] 'requests' library not available. Cannot use IP-based location.")
        return None

    # Try a public IP geolocation API (no API key required for basic usage)
    # Using ipapi.co which returns JSON with 'latitude' and 'longitude' fields.
    url = "https://ipapi.co/json/"

    try:
        resp = requests.get(url, timeout=timeout)
        resp.raise_for_status()
        data = resp.json()

        lat = data.get("latitude") or data.get("lat")
        lon = data.get("longitude") or data.get("lon")

        if lat is None or lon is None:
            print("[IPGeo] IP API did not return latitude/longitude.")
            return None

        lat_f = float(lat)
        lon_f = float(lon)
        print(f"[IPGeo] IP-based location: {lat_f:.6f}, {lon_f:.6f}")
        return lat_f, lon_f

    except Exception as e:
        print(f"[IPGeo] Failed to get IP-based location: {e}")
        return None



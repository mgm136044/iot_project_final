#!/usr/bin/env python3
# test_emergency_sms.py
"""
긴급 신고 SMS 내용 미리보기 스크립트.

실제 SOLAPI로 SMS를 보내지 않고, 현재 ReportManager 로직이 생성하는
메시지 텍스트와 위치/맵 링크를 콘솔에 출력한다.
"""

import os
import sys
import datetime


def main():
    # 프로젝트 루트(iot_project_OOP) 기준 경로 세팅
    project_root = os.path.dirname(os.path.abspath(__file__))
    if project_root not in sys.path:
        sys.path.insert(0, project_root)

    # 필요한 모듈 임포트
    import config  # noqa: E402
    from driver_monitor.logging_system.event_logger import EventLogger  # noqa: E402
    from driver_monitor.sensors.gps_manager import GPSManager  # noqa: E402
    from driver_monitor.report.report_manager import ReportManager  # noqa: E402

    print("=== Emergency SMS Preview ===")
    print(f"- Time: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"- SMS_ENABLED: {getattr(config, 'SMS_ENABLED', False)}")
    print(f"- GPS_ENABLED: {getattr(config, 'GPS_ENABLED', False)}")
    print("")

    # 1) GPSManager 준비 (실제 코드와 동일한 방식)
    import importlib

    importlib.reload(config)
    gps_simulate = not getattr(config, "GPS_ENABLED", True)
    gps = GPSManager(simulate=gps_simulate)
    gps.initialize()

    # 2) ReportManager + Dummy SMS Service 구성
    logger = EventLogger()
    report_manager = ReportManager(logger=logger, gps_manager=gps)

    class DummyGroupCount:
        def __init__(self):
            self.total = 1
            self.registered_success = 1
            self.registered_failed = 0

    class DummyGroupInfo:
        def __init__(self):
            self.group_id = "DUMMY-GROUP-ID"
            self.count = DummyGroupCount()

    class DummyResponse:
        def __init__(self):
            self.group_info = DummyGroupInfo()

    class DummySMSService:
        def send(self, message):
            # 실제 전송 대신 내용만 출력
            print("=== SMS MESSAGE PREVIEW ===")
            print(f"From: {message.from_}")
            print(f"To  : {message.to}")
            print("---- Text ----")
            print(message.text)
            print("--------------")
            return DummyResponse()

    # SOLAPI가 설치되어 있지 않더라도, 강제로 더미 서비스로 덮어쓴다.
    report_manager.sms_service = DummySMSService()

    # 3) 임의의 충격 시각을 등록해서 _send_sms_report를 호출
    #    (실제 코드에서는 impact 이후 조건 충족 + 무응답 시 이 함수가 호출됨)
    report_manager.last_impact_time = datetime.datetime.now() - datetime.timedelta(seconds=30)

    print("Calling _send_sms_report() in preview mode (no real SMS will be sent)...")
    report_manager._send_sms_report()

    # 4) 정리
    gps.close()
    print("=== Preview complete ===")


if __name__ == "__main__":
    main()



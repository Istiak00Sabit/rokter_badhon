#!/usr/bin/env python3
"""Android accessibility smoke using ONLY synthetic local Firebase fixtures.

No screenshots, personal information, or production user identities are logged.
This is limited cloud-emulator acceptance, NOT physical-device acceptance.
"""
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

PACKAGE = "com.example.rokter_badhon"
PHONE = "01000000000"  # Public emulator-only synthetic identity
PASSWORD = "123456"


def run(*args, timeout=25):
    return subprocess.run(
        list(args), text=True, capture_output=True, timeout=timeout,
        check=True,
    ).stdout


def adb(*args, timeout=25):
    return run("adb", *args, timeout=timeout)


def nodes():
    adb("shell", "uiautomator", "dump", "/sdcard/rokter-ui.xml", timeout=40)
    xml = adb("exec-out", "cat", "/sdcard/rokter-ui.xml", timeout=20)
    tree = ET.fromstring(xml)
    return list(tree.iter("node"))


def node_labels(node):
    # Flutter may expose the same string as both text and content-desc.
    # Joining them produces "Sign in Sign in" and breaks exact matching.
    return tuple(
        x.strip() for x in (node.get("text", ""), node.get("content-desc", ""))
        if x and x.strip()
    )


def label(node):
    return " ".join(dict.fromkeys(node_labels(node)))


# Strict allowlist: never output arbitrary rendered UI or personal records.
SAFE_UI_LABELS = (
    "English", "বাংলা", "Login", "Sign in",
    "Access your account", "আপনার অ্যাকাউন্টে প্রবেশ করুন",
    "Language", "ভাষা", "Donors", "Committee",
    "Profile", "Current committee",
    "Demo Firebase initialization unavailable",
    "Demo Firebase emulator unavailable",
)


def safe_ui_state(data):
    return {word: any(
        word == x or x.startswith(word + " ")
        for node in data for x in node_labels(node)
    ) for word in SAFE_UI_LABELS}


def bounds(node):
    match = re.fullmatch(
        r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", "")
    )
    if not match:
        return None
    l, t, r, b = (int(x) for x in match.groups())
    return (l + r) // 2, (t + b) // 2


def select_node(data, term, exact=False):
    matches = []
    for node in data:
        parts = node_labels(node)
        if any((part == term if exact else term.casefold() in part.casefold())
               for part in parts):
            point = bounds(node)
            if point:
                box = node.get("bounds", "")
                w = [int(x) for x in re.findall(r"\d+", box)]
                area = max(1, (w[2] - w[0]) * (w[3] - w[1]))
                matches.append((area, node))
    if not matches:
        return None
    return min(matches, key=lambda pair: pair[0])[1]


def safe_android_runtime_state(data):
    """Coarse non-personal diagnostics; never print raw UI or logcat."""
    node_count = len(data)
    types = [item.get("class", "") for item in data]
    foreground = adb("shell", "dumpsys", "activity", "activities")
    own_process = bool(adb("shell", "pidof", PACKAGE).strip())
    return {
        "nodes": node_count,
        "edit_fields": sum("EditText" in name for name in types),
        "flutter_view": any("FlutterView" in name for name in types),
        "package_foreground": (
            "mResumedActivity" in foreground and PACKAGE in foreground
        ) or ("topResumedActivity" in foreground and PACKAGE in foreground),
        "process_alive": own_process,
    }


def safe_flutter_error_flags():
    try:
        logs = adb("logcat", "-d", "-s", "flutter:E", "AndroidRuntime:E",
                   timeout=25)
    except subprocess.SubprocessError:
        return {"logcat_readable": False}
    checks = {
        "firebase_core_error": ("firebase_core", "FirebaseCore", "core/duplicate-app"),
        "firebase_config_error": ("api-key", "APIKey", "Invalid FirebaseOptions"),
        "flutter_unhandled_error": ("Unhandled Exception", "Unhandled exception"),
        "android_fatal": ("FATAL EXCEPTION",),
    }
    return {key: any(marker in logs for marker in markers)
            for key, markers in checks.items()}


def retry(predicate, label_for_error, seconds=45):
    deadline = time.monotonic() + seconds
    last_error = None
    last_allowed_state = {}
    last_nodes = []
    while time.monotonic() < deadline:
        try:
            snapshot = nodes()
            last_nodes = snapshot
            last_allowed_state = safe_ui_state(snapshot)
            if any(has_label(snapshot, msg) for msg in (
                "Demo Firebase initialization unavailable",
                "Demo Firebase emulator unavailable",
            )):
                raise AssertionError(
                    "Android UI acceptance: demo Firebase startup unavailable; "
                    "no production fallback"
                )
            found = predicate(snapshot)
            if found is not None:
                return found
        except (ET.ParseError, subprocess.SubprocessError) as exc:
            last_error = type(exc).__name__
        time.sleep(2)
    # Report booleans for public UI labels only; no XML or typed field values.
    visible = sorted(k for k, value in last_allowed_state.items() if value)
    runtime = safe_android_runtime_state(last_nodes)
    errors = safe_flutter_error_flags()
    raise AssertionError(
        f"Android UI acceptance: {label_for_error} not found "
        f"(allowed labels visible: {visible}; "
        f"runtime: {runtime}; error categories: {errors}; "
        f"capture: {last_error or 'available'})"
    )


def tap(node):
    x, y = bounds(node)
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(1)


def enter(node, value):
    tap(node)
    adb("shell", "input", "text", value)
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(1)


def textfields(data):
    return [
        node for node in data
        if "EditText" in node.get("class", "") and bounds(node)
    ]


def has_label(data, value):
    return select_node(data, value, exact=True) is not None


def ensure_demo():
    if os.getenv("GITHUB_ACTIONS") != "true" or os.getenv("CI") != "true":
        raise AssertionError("Android acceptance requires ephemeral CI.")
    if os.getenv("FIRESTORE_EMULATOR_HOST") != "127.0.0.1:8080":
        raise AssertionError("Firestore demo emulator not configured.")
    if os.getenv("FIREBASE_AUTH_EMULATOR_HOST") != "127.0.0.1:9099":
        raise AssertionError("Auth demo emulator not configured.")
    for port in (8080, 9099):
        adb("reverse", f"tcp:{port}", f"tcp:{port}")


def main():
    ensure_demo()
    # Verify the unauthenticated landing page and the language switch on a
    # real cloud Android environment with the local Auth emulator reachable.
    retry(lambda data: data if has_label(data, "English") else None,
          "login screen language control", seconds=65)
    english = retry(lambda data: select_node(data, "English", exact=True),
                    "English language button")
    tap(english)
    retry(lambda data: data if (
        has_label(data, "Sign in") and
        has_label(data, "Access your account")
    ) else None, "English login heading and subtitle")
    snapshot = retry(lambda data: data if len(textfields(data)) >= 2 else None,
                     "phone and password input accessibility")
    inputs = textfields(snapshot)
    enter(inputs[0], PHONE)
    snapshot = retry(lambda data: data if len(textfields(data)) >= 2 else None,
                     "password field after phone input")
    enter(textfields(snapshot)[1], PASSWORD)
    login = retry(lambda data: select_node(data, "Login", exact=True),
                  "submit login button")
    tap(login)

    # Auth admission is only possible through local synthetic AuthLink+User,
    # so reaching protected bottom navigation proves real emulator login.
    main_nav = retry(
        lambda data: data if (
            has_label(data, "Donors") and has_label(data, "Committee") and
            has_label(data, "Profile")
        ) else None,
        "admitted bottom navigation after synthetic login",
        seconds=75,
    )
    print("Android UI: English language switch + demo Auth login: PASS")
    committee = select_node(main_nav, "Committee", exact=True)
    tap(committee)
    retry(lambda data: data if has_label(data, "Current committee") else None,
          "committee page heading")
    # Logout/login and complete registration flows are not exercised here.
    print("Android UI: committee navigation: PASS (synthetic emulator)")
    print("Android UI acceptance: PASS; physical device and production remain NO-GO")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, subprocess.SubprocessError, ET.ParseError) as exc:
        # Deliberately do not dump UI trees, account data, or authentication
        # credentials to public logs.
        print("Android UI acceptance: FAIL: " + str(exc), file=sys.stderr)
        sys.exit(1)

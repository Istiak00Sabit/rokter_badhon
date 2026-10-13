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


def label(node):
    return " ".join(
        node.get(attr, "") for attr in ("text", "content-desc")
    ).strip()


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
        text = label(node)
        if (text == term if exact else term.lower() in text.lower()):
            point = bounds(node)
            if point:
                box = node.get("bounds", "")
                w = [int(x) for x in re.findall(r"\d+", box)]
                area = max(1, (w[2] - w[0]) * (w[3] - w[1]))
                matches.append((area, node))
    if not matches:
        return None
    return min(matches, key=lambda pair: pair[0])[1]


def retry(predicate, label_for_error, seconds=45):
    deadline = time.monotonic() + seconds
    last_error = None
    while time.monotonic() < deadline:
        try:
            snapshot = nodes()
            found = predicate(snapshot)
            if found is not None:
                return found
        except (ET.ParseError, subprocess.SubprocessError) as exc:
            last_error = type(exc).__name__
        time.sleep(2)
    raise AssertionError(
        f"Android UI acceptance: {label_for_error} not found "
        f"(last UI capture state: {last_error or 'no matching node'})"
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
    retry(lambda data: data if has_label(data, "Sign in") else None,
          "English login heading")
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

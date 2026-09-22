// SDDM greeter styled as a login-screen twin of ../../config/hypr/hyprlock.conf.
//
// The layout is deliberately the lock screen's: blurred wallpaper, a large
// clock hard against the top-right with the long-form date beneath it, and one
// centred field carrying a thick accent outline. Everything a LOCK screen does
// not need but a LOGIN screen does — choosing a session, powering the machine
// off — is pushed to the bottom corners as small type, so the centre of the
// screen stays as quiet as hyprlock's.
//
// Every colour, size and format is a key in theme.conf, which ../sddm.nix
// generates from one Catppuccin palette. Nothing here should ever need editing
// to re-colour the greeter; edit the Nix.
import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: Screen.width
    height: Screen.height

    // --- palette / metrics, all from theme.conf -----------------------------
    readonly property string cBase: config.Base
    readonly property string cSurface0: config.Surface0
    readonly property string cText: config.Text
    readonly property string cSubtext0: config.Subtext0
    readonly property string cAccent: config.Accent
    readonly property string cRed: config.Red
    readonly property string cYellow: config.Yellow
    readonly property string fontFamily: config.Font

    // --- per-monitor scale ---------------------------------------------------
    // Everything below theme.conf is authored at scale 1.0 and multiplied by
    // this, so the greeter grows on a dense panel exactly as the rest of the
    // desktop does. On this laptop that is 1.25 on the built-in panel and 1.0
    // on the external — the same numbers niri picks.
    //
    // THE GREETER CANNOT ASK NIRI. It runs before any session exists, so the
    // scale has to be DERIVED, and the only way to land on niri's number is to
    // run niri's own algorithm. niri's src/utils/scale.rs says it "follows logic
    // and tests from Mutter" (meta-monitor.c): aim for a target DPI of 135 on
    // panels under 20" diagonal and 110 on anything larger, then snap to the
    // nearest quarter step that still leaves at least 800x480 logical pixels.
    // Checked against both of this machine's panels — 310x170mm/1920x1080 gives
    // 1.25 and 530x300mm/1920x1080 gives 1.0, which is what `niri msg outputs`
    // reports for them.
    //
    // ../../../config/hypr/hyprlock-config.sh derives the lock screen's scale the
    // SAME way, off the same EDID millimetres, so the two screens stay in
    // parity by construction. Change the rule here and change it there too.
    //
    // The one case this gets wrong is an explicit `scale` in a niri output
    // block: niri would obey it and both of these would go on guessing. There
    // is no such override today; if one is ever added, both sides need telling.
    readonly property real uiScale: guessMonitorScale()

    function guessMonitorScale() {
        // Screen.pixelDensity is physical dots per mm, i.e. QScreen's
        // physicalDotsPerInch / 25.4, which is already the average of the X and
        // Y axes. Averaging first and taking the diagonal after is worth a few
        // tenths of a DPI and never a quarter-step, so the shortcut is safe:
        // with one density the diagonal in inches is just diagPx / dpi.
        var dpi = Screen.pixelDensity * 25.4
        // An output with no EDID size reports 0mm and Qt hands back a nonsense
        // density. niri returns 1.0 for exactly this case; so do we.
        if (!(dpi > 0))
            return 1

        var diagPx = Math.sqrt(Screen.width * Screen.width
                               + Screen.height * Screen.height)
        var targetDpi = (diagPx / dpi) < 20 ? 135 : 110
        var perfect = dpi / targetDpi

        // MIN_SCALE 1 to MAX_SCALE 4 in quarter steps, skipping any that would
        // shrink the logical area below MIN_LOGICAL_AREA (800x480).
        var best = 1
        var bestErr = Number.POSITIVE_INFINITY
        for (var step = 4; step <= 16; step++) {
            var s = step / 4
            if (Math.round(Screen.width / s) * Math.round(Screen.height / s)
                    < 800 * 480)
                continue
            var err = Math.abs(s - perfect)
            if (err < bestErr) {
                bestErr = err
                best = s
            }
        }
        return best
    }

    // theme.conf's numbers, scaled. Rounding here rather than at each use keeps
    // the outline, the pill radius and the dot row landing on whole pixels.
    //
    // whole() EXISTS TO STOP A SILENT ZERO. Every property below is an `int`,
    // and a QML binding that evaluates to NaN — one undefined name anywhere in
    // the expression is enough — does not throw. It fails the assignment with
    // "Unable to assign double to int" on stderr and leaves the property at 0.
    // On a login screen that is invisible: a 0px dot draws nothing and a 0px
    // font renders nothing, so the field simply stops showing that you typed,
    // with no error anywhere a user would look. That is exactly how this
    // shipped broken once. Anything non-finite now falls back to the unscaled
    // value instead, which is wrong-looking but never blank.
    function whole(v, fallback) {
        var n = Math.round(v)
        return isFinite(n) ? n : fallback
    }
    function px(v) { return whole(parseInt(v) * root.uiScale, parseInt(v) || 0) }

    readonly property int margin: px(config.Margin)
    readonly property int timeSize: px(config.TimeSize)
    readonly property int dateSize: px(config.DateSize)
    readonly property int fieldWidth: px(config.FieldWidth)
    readonly property int fieldHeight: px(config.FieldHeight)
    readonly property int fieldOffsetY: px(config.FieldOffsetY)
    readonly property int outlineWidth: px(config.OutlineWidth)
    readonly property int statusFontSize: px(config.StatusFontSize)

    // DERIVED FROM THE SCALED FIELD HEIGHT, NOT SCALED THEMSELVES — and the
    // difference is not cosmetic. hyprlock computes all three of these from the
    // input-field's height every time it draws (PasswordInputField.cpp), so once
    // the field grows they are recomputed from the GROWN height, which is not
    // the same as multiplying the values it had at scale 1.0:
    //
    //   height 54 -> dot nearbyint(54*0.2*0.5)*2 = 10   (10 * 1.25 = 13 too)
    //   height 68 -> dot nearbyint(68*0.2*0.5)*2 = 14   but 10 * 1.25 = 13
    //
    // A 13px dot against hyprlock's 14px was exactly the kind of drift these two
    // screens are supposed to never have. Same for the placeholder, which
    // hyprlock sizes at (int)(height / 4) POINTS — 17pt at height 68, i.e.
    // 22.7px, where scaling the 17px it uses at height 54 would give 21px.
    //
    // At scale 1.0 these reproduce theme.conf's old DotSize/DotsSpacing/
    // FieldFontSize exactly (10, 2, 17), which is why those keys are gone: they
    // were only ever this arithmetic, precomputed for one scale.
    //
    // EVERY REFERENCE HERE IS `root.`-QUALIFIED ON PURPOSE. The first cut of
    // these three wrote bare `fieldHeight` / `dotSize`, and on the real greeter
    // — though never in any offscreen harness — those resolved to undefined,
    // took the whole expression to NaN and zeroed all three. Unqualified names
    // in a binding are resolved against a scope chain that is not the same in
    // every context the greeter builds this file in; spelling out the object
    // removes the question entirely, and is the form the QML linter wants too.
    readonly property int dotSize: whole(root.fieldHeight * 0.2 * 0.5, 5) * 2
    readonly property int dotsSpacing: whole(Math.floor(root.dotSize * 0.2), 2)
    readonly property int fieldFontSize: whole(Math.floor(root.fieldHeight / 4) * 4 / 3, 17)

    // The username is never typed. SDDM records the last successful login in
    // /var/lib/sddm/state.conf and exposes it here; on a fresh install (no
    // state file yet) it is empty, so fall back to the first account rather
    // than presenting an unlabelled box.
    property string currentUser: userModel.lastUser !== ""
                                 ? userModel.lastUser
                                 : (userModel.count > 0
                                    ? userModel.data(userModel.index(0, 0), Qt.UserRole + 1)
                                    : "")
    property string errorText: ""
    property int failCount: 0

    // --- state shared between MONITORS ---------------------------------------
    // On a multi-monitor machine SDDM does not draw one greeter across the
    // desktop: GreeterApp::addViewForScreen() gives every screen its own
    // QQuickView, built with a bare `new QQuickView()` — so every screen also
    // gets its own QQmlEngine, and this file is instantiated once per monitor
    // with NOTHING in common between the copies. Left alone, that means one
    // password field per screen, each filling up independently; only the screen
    // holding keyboard focus (SDDM activates the primary one) would show what
    // was typed, and picking a session on one screen would not apply to an
    // Enter pressed on the other. The lock screen has no such split — hyprlock
    // is a single process painting one password state onto every output — and
    // this brings the greeter to the same behaviour.
    //
    // The ONLY shared, writable thing the per-screen engines can both reach is
    // `config`. It is an SDDM::ThemeConfig, i.e. a QQmlPropertyMap, handed to
    // every view's root context as the same C++ instance; it overrides neither
    // updateValue() nor freeze(), so QML may write to it, and a write activates
    // the key's notify signal in every engine that has a binding on it.
    //
    // A QML `pragma Singleton` would be the obvious tool and does NOT work
    // here, precisely because singletons are per-engine.
    //
    // All three mirrors below are BINDINGS, not Connections handlers. A
    // QQmlPropertyMap key's notify signal is anonymous (`__N()`), so there is no
    // `onSharedPasswordChanged` to connect to on `config` itself — only a
    // binding picks the change up. Each mirror is guarded by an inequality, so
    // the write-out and read-back cannot loop.
    //
    // ../sddm.nix declares all three keys in theme.conf. They must already
    // exist when these bindings are created, or they would never be notified.
    readonly property string sharedPassword: config.SharedPassword
    onSharedPasswordChanged: {
        if (passwordField.text !== root.sharedPassword)
            passwordField.text = root.sharedPassword
    }

    // TRUE BETWEEN ENTER AND PAM'S VERDICT, and mirrored like the password so
    // the other monitor holds its dots too instead of still offering to log
    // in. Never cleared on success, because there is no success to handle: SDDM
    // stops the greeter ~100ms after the authentication succeeds.
    //
    // It also makes the field UNSUBMITTABLE for the duration, which is the part
    // that fixes a real lost keystroke rather than just looking better. SDDM
    // answers a second Login message with "Existing authentication ongoing,
    // aborting" and throws it away — so a greeter that stays silent and
    // accepting through a slow check trains you to press Enter again and then
    // ignores it. The check used to take TEN SECONDS (pam_fprintd, see
    // ../../hardware/fingerprint.nix) and pressing Enter twice was the normal
    // reaction to it; the wait is short again now, but "silent and still
    // accepting Enter" is the shape of the bug, not the length of the wait.
    readonly property string sharedChecking: config.SharedChecking
    property bool checking: false
    onSharedCheckingChanged: {
        var c = (root.sharedChecking === "1")
        if (c !== root.checking)
            root.checking = c
    }
    onCheckingChanged: {
        var s = root.checking ? "1" : ""
        if (config.SharedChecking !== s)
            config.SharedChecking = s
    }

    // Empty until someone opens the menu; until then every screen independently
    // shows sessionModel.lastIndex, which is the same value everywhere anyway.
    readonly property string sharedSession: config.SharedSession
    property int sessionIndex: sessionModel.lastIndex
    onSharedSessionChanged: {
        // parseInt() of anything unexpected is NaN, and sessionIndex is an int,
        // so assigning it would fail the same silent way the metrics above did
        // — except the casualty here is which session actually gets launched.
        var i = parseInt(root.sharedSession)
        if (isFinite(i) && i >= 0 && i !== root.sessionIndex)
            root.sessionIndex = i
    }

    Rectangle {
        anchors.fill: parent
        color: root.cBase
        z: 0
    }

    // Claims an arrow for the WHOLE greeter surface. Without this, any area
    // where no QML item sets a cursor shows whatever the X root window cursor
    // is — and SDDM's attempt to set that (`xsetroot -cursor_name left_ptr` in
    // XorgDisplayServer.cpp) fails on NixOS unless xsetroot is on the
    // display-manager unit's PATH, which ../sddm.nix now puts there. Setting
    // the shape here means the pointer is a themed arrow whether or not that
    // call succeeds, and on Wayland where it never runs at all.
    //
    // z:0 and acceptedButtons: Qt.NoButton keep it inert: it is under every
    // control, and the session and power rows override the shape on hover.
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.ArrowCursor
    }

    // Pre-blurred in the Nix derivation rather than at runtime: QML's blur
    // lives in Qt5Compat.GraphicalEffects, an extra QML module on the greeter's
    // import path purely for one effect, and blurring a 4K image every time the
    // greeter starts is work the build can do once.
    Image {
        anchors.fill: parent
        source: config.Background
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        mipmap: true
        clip: true
        z: 1
    }

    // --- clock, top-right ---------------------------------------------------
    // Mirrors hyprlock's two top-right `label` blocks, which sit at -30,-30 and
    // -30,-149. Their font_size is 68 and 19 against the 90 and 25 used here,
    // and that is not drift: hyprlock's numbers are POINTS resolved by pango at
    // 96 DPI, these are pixels, and 68 * 4/3 = 90. See the note in ../sddm.nix.
    Column {
        z: 3
        spacing: 0
        anchors {
            top: parent.top
            right: parent.right
            topMargin: root.margin
            rightMargin: root.margin
        }

        Text {
            id: timeLabel
            anchors.right: parent.right
            renderType: Text.NativeRendering
            color: root.cText
            font.family: root.fontFamily
            font.pixelSize: root.timeSize
            font.bold: true
            text: Qt.formatDateTime(new Date(), config.TimeFormat)
        }

        Text {
            id: dateLabel
            anchors.right: parent.right
            renderType: Text.NativeRendering
            color: root.cSubtext0
            font.family: root.fontFamily
            font.pixelSize: root.dateSize
            text: Qt.formatDateTime(new Date(), config.DateFormat)
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            timeLabel.text = Qt.formatDateTime(new Date(), config.TimeFormat)
            dateLabel.text = Qt.formatDateTime(new Date(), config.DateFormat)
        }
    }

    // --- the one field, centred ---------------------------------------------
    Item {
        z: 3
        // hyprlock's `size` is the INNER box and its outline is drawn OUTSIDE
        // that, so the 280x54 field with outline_thickness 4 occupies 288x62 on
        // screen. Qt insets a Rectangle's border instead, so the outer box has
        // to be grown by the outline on both sides to put the same number of
        // pixels in the same places — without this the greeter drew the whole
        // field 8px narrower and shorter than the lock screen's.
        width: root.fieldWidth + 2 * root.outlineWidth
        height: root.fieldHeight + 2 * root.outlineWidth
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        // hyprlock's `position = 0, -20` on a centre-aligned input-field, i.e.
        // 20px below the middle of the screen rather than dead centre.
        anchors.verticalCenterOffset: root.fieldOffsetY

        TextField {
            id: passwordField
            anchors.fill: parent
            focus: true

            // THE FIELD MUST NEVER QUIETLY LOSE FOCUS. There is no caret here
            // (see cursorDelegate below), so an unfocused field is visually
            // identical to a focused one — you would type a password and watch
            // nothing happen, with nothing on screen explaining why.
            //
            // The one thing allowed to hold focus instead is the session menu,
            // which needs arrow keys and Enter while it is open. Everything
            // else — the power labels, a click on the background — hands focus
            // straight back. Qt.callLater defers the grab out of the signal
            // that reported the loss, which would otherwise re-enter.
            onActiveFocusChanged: {
                if (!activeFocus && !sessionMenu.visible)
                    Qt.callLater(passwordField.forceActiveFocus)
            }

            echoMode: TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            selectByMouse: true
            selectionColor: root.cAccent
            renderType: Text.NativeRendering
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            font.family: root.fontFamily
            font.pixelSize: root.fieldFontSize

            // The masking dots are NOT drawn by this TextField — see the dots
            // Item below. Its own echo characters are made invisible rather
            // than disabled, because echoMode still has to be Password so the
            // real text never reaches the screen.
            color: "transparent"

            background: Rectangle {
                color: root.cSurface0
                // hyprlock leaves input-field `rounding` at its default -1,
                // which its IWidget::roundingForBorderBox resolves to
                // min(w,h)/2 — a full pill, not a rounded rectangle. Deriving
                // it from the height rather than hardcoding 30 keeps it a pill
                // if FieldHeight is ever changed.
                radius: height / 2
                // hyprlock's outline_thickness = 4, in its accent colour. The
                // outline turns yellow while caps lock is on, exactly as
                // hyprlock's capslock_color does.
                border.width: root.outlineWidth
                border.color: keyboard.capsLock ? root.cYellow : root.cAccent
            }

            // hyprlock has no text caret at all — it draws dots and nothing
            // else — so there is none here either. An empty delegate replaces
            // the caret with something that renders nothing; verified honoured
            // by swapping in a red Rectangle, which does render a red bar.
            //
            // Note that `cursorVisible: false` would NOT work on its own:
            // TextInput assigns to that property itself on focus changes and on
            // every tick of its blink timer, destroying any binding to it.
            cursorDelegate: Item { }

            onAccepted: root.attemptLogin()
            // Publishing the text here rather than in a Keys handler is what
            // makes the mirror cover everything that can change it — typing,
            // paste, select-and-delete, and the clear on a failed attempt.
            // Assignments coming back FROM another screen land here too, which
            // is what the guard is for.
            onTextChanged: {
                root.errorText = ""
                if (root.sharedPassword !== text)
                    config.SharedPassword = text
            }
        }

        // THE MASKING DOTS, drawn here rather than left to the TextField's own
        // echo characters. Doing it by hand is what makes them match hyprlock
        // exactly, and it is the only way to reproduce the animation.
        //
        // hyprlock's geometry, from PasswordInputField.cpp:
        //   diameter  nearbyint(h * dots_size * 0.5) * 2   — 10px at h=54
        //   spacing   floor(diameter * dots_spacing)       — 2px
        //   rounding  diameter / 2 when dots_rounding = -1 — a true circle
        //   width     (diameter + spacing) * N - spacing   — trailing gap removed
        // and the row stays centred in the field.
        //
        // Driving it off an ANIMATED count is what produces the typing effect:
        // hyprlock animates dots.currentAmount toward the password length and
        // uses the fractional part as the newest dot's alpha, so a dot fades in
        // while the whole row slides to stay centred. Both fall out of animating
        // this one number.
        Item {
            id: dots
            // THE INNER BOX, not the outer one. hyprlock lays its dots out in
            // `inputFieldBox`, which is the field WITHOUT the outline, and the
            // padding and scroll arithmetic below is written in those
            // coordinates. Centring on its own could not tell the two apart —
            // the outline is symmetric, so it cancels — which is why filling
            // the parent was good enough until the row got long enough to need
            // the edges of the box.
            anchors.fill: parent
            anchors.margins: root.outlineWidth
            z: 2

            readonly property int size: root.dotSize
            readonly property int gap: root.dotsSpacing
            property real count: 0

            // hyprlock's names, from the same draw():
            //   DOTPAD        (h - passSize.y) / 2
            //   DOTAREAWIDTH  w - DOTPAD * 2
            //   MAXDOTS       round(DOTAREAWIDTH / (passSize.x + passSpacing))
            //   CURRWIDTH     (passSize.x + passSpacing) * CURRDOTS - passSpacing
            readonly property real pad: (height - size) / 2
            readonly property real areaWidth: width - pad * 2
            readonly property int maxDots: Math.round(areaWidth / (size + gap))
            readonly property real rowWidth: (size + gap) * count - gap

            // PAST maxDots THE ROW SCROLLS AND THE FIELD DOES NOT GROW. This
            // is hyprlock's second `xstart` branch verbatim; it parks the
            // newest dot against the right of the dot area and lets the oldest
            // fall off the left, so a long password stays inside the pill. The
            // greeter had no such branch and went on centring a row that kept
            // getting wider, so past ~20 characters the dots simply marched out
            // of the box in both directions and over the wallpaper.
            readonly property real xstart: count > maxDots
                ? (width + maxDots * (size + gap) - gap - 2 * rowWidth) / 2
                : (areaWidth - rowWidth) / 2 + pad

            Behavior on count {
                NumberAnimation {
                    duration: parseInt(config.DotsAnimationMs)
                    easing.type: Easing.OutCubic
                }
            }

            // FROZEN WHILE A CHECK IS IN FLIGHT. What keeps the dots on screen
            // for the wait is simply that attemptLogin() does not clear the
            // field; this guard is the narrower case of TYPING during the
            // wait, which would otherwise grow the row. hyprlock refuses the
            // same update in the same place:
            //
            //     if (checkWaiting && configCheckText.empty())
            //         return;     // updateDots(), dot count left alone
            //
            // so on neither screen does anything typed after Enter show up.
            Connections {
                target: passwordField
                function onTextChanged() {
                    if (!root.checking)
                        dots.count = passwordField.text.length
                }
            }

            Repeater {
                model: Math.ceil(dots.count)
                delegate: Rectangle {
                    readonly property int floored: Math.floor(dots.count)
                    readonly property real frac: dots.count - floored

                    width: dots.size
                    height: dots.size
                    radius: width / 2
                    color: root.cText
                    y: (dots.height - height) / 2
                    x: dots.xstart + index * (dots.size + dots.gap)
                    // hyprlock's `if (i < DOTFLOORED - MAXDOTS) continue`.
                    visible: index >= floored - dots.maxDots
                    // Both ENDS of a row in motion are faded, not just the new
                    // one: hyprlock scales fontCol.a by (CURRDOTS - DOTFLOORED)
                    // for the dot being typed and by its complement for the one
                    // scrolling off, so the row slides rather than jumps.
                    opacity: frac === 0
                             ? 1
                             : (index === floored
                                ? frac
                                : (index === floored - dots.maxDots ? 1 - frac : 1))
                }
            }
        }

        // hyprlock's placeholder_text, reproduced run for run. Its markup is
        //   <span foreground="#cdd6f4"><i>󰌾 Logged in as </i>
        //   <span foreground="#cba6f7">valer</span></span>
        // — so the prompt is full-strength text and ITALIC, while the username
        // is accent-coloured and UPRIGHT. Italicising the whole string (or
        // dimming the prompt to subtext) both read as visibly different from
        // the lock screen. A TextField's own placeholderText cannot be styled
        // per-run, so this is an overlay shown only while the field is empty.
        //
        // It stays HIDDEN through a check, because the field is not cleared on
        // submit and the frozen dots keep it non-empty. hyprlock's draw() skips
        // its placeholder for the same window whenever check_text is unset, so
        // neither screen puts a message where the dots are.
        Text {
            anchors.centerIn: parent
            visible: passwordField.text.length === 0
            renderType: Text.NativeRendering
            textFormat: Text.StyledText
            font.family: root.fontFamily
            font.pixelSize: root.fieldFontSize
            color: root.cText
            text: "<i>󰌾 Logged in as </i><font color=\"" + root.cAccent + "\">"
                  + root.currentUser + "</font>"
        }

        // The X server parks the pointer at the exact centre of the screen on
        // every start, which lands inside this field. Qt's TextField shows an
        // I-BEAM on hover, and a thin vertical bar sitting in a password box is
        // indistinguishable from a text caret — it is what the "caret" in this
        // theme turned out to be, long after the real one was removed.
        // hyprlock avoids the whole question with hide_cursor = true, but the
        // greeter still needs a visible pointer for the session and power
        // controls, so the field gets a plain arrow instead.
        //
        // acceptedButtons: Qt.NoButton means this only claims the cursor shape:
        // presses fall through to the TextField underneath, so clicking to
        // focus still works.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.ArrowCursor
        }
    }

    // --- status line under the field ----------------------------------------
    // Occupies the slot hyprlock gives $FAIL and $FPRINTPROMPT. Caps lock gets
    // priority because it is the likeliest cause of a rejected password.
    Text {
        z: 3
        anchors {
            top: parent.verticalCenter
            topMargin: root.fieldHeight + root.fieldOffsetY
            horizontalCenter: parent.horizontalCenter
        }
        renderType: Text.NativeRendering
        textFormat: Text.StyledText
        font.family: root.fontFamily
        font.pixelSize: root.statusFontSize
        font.italic: true
        color: keyboard.capsLock ? root.cYellow : root.cRed
        // Mirrors hyprlock's `fail_text = <i>$FAIL <b>($ATTEMPTS)</b></i>`,
        // attempt counter and all.
        text: keyboard.capsLock
              ? "Caps Lock is on"
              : (root.errorText === ""
                 ? ""
                 : root.errorText + " <b>(" + root.failCount + ")</b>")
    }

    // --- session picker, bottom-left ----------------------------------------
    Text {
        id: sessionButton
        z: 3
        anchors {
            left: parent.left
            bottom: parent.bottom
            leftMargin: root.margin
            bottomMargin: root.margin
        }
        renderType: Text.NativeRendering
        font.family: root.fontFamily
        font.pixelSize: root.statusFontSize
        color: sessionArea.containsMouse ? root.cAccent : root.cSubtext0
        text: sessionModel.data(sessionModel.index(root.sessionIndex, 0),
                                Qt.UserRole + 4) + " ▾"

        MouseArea {
            id: sessionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sessionMenu.open()
        }

        // Styled end to end. A bare QtQuick Controls Menu renders in the
        // default light palette — a white box with black text — which is
        // jarring against everything else here. Both the popup chrome and the
        // per-entry delegate have to be replaced to avoid that; setting only
        // the background leaves the item text and highlight stock.
        Menu {
            id: sessionMenu
            y: -height - root.px(8)
            padding: root.px(6)

            // Hand focus back the moment the menu goes away, whether an entry
            // was picked or it was dismissed. Without this the greeter is left
            // with nothing focused and silently swallows typing.
            onClosed: passwordField.forceActiveFocus()

            background: Rectangle {
                implicitWidth: root.px(240)
                color: root.cSurface0
                radius: root.px(12) // the waybar/swaync corner
                border.width: 1
                border.color: root.cAccent
            }

            Instantiator {
                model: sessionModel
                onObjectAdded: (i, obj) => sessionMenu.insertItem(i, obj)
                onObjectRemoved: (i, obj) => sessionMenu.removeItem(obj)
                delegate: MenuItem {
                    id: sessionItem
                    text: model.name
                    implicitHeight: root.px(34)

                    contentItem: Text {
                        text: sessionItem.text
                        renderType: Text.NativeRendering
                        font.family: root.fontFamily
                        font.pixelSize: root.statusFontSize
                        color: sessionItem.highlighted ? root.cBase : root.cText
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: root.px(10)
                    }

                    background: Rectangle {
                        color: sessionItem.highlighted ? root.cAccent : "transparent"
                        radius: root.px(8)
                    }

                    // Through `config`, not straight into root.sessionIndex:
                    // attemptLogin() runs on whichever screen has focus, and
                    // it must launch the session picked on EITHER of them.
                    onTriggered: config.SharedSession = String(model.index)
                }
            }
        }
    }

    // --- power actions, bottom-right ----------------------------------------
    Row {
        z: 3
        spacing: root.px(16)
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: root.margin
            bottomMargin: root.margin
        }

        // Shown unconditionally rather than gated on sddm.canSuspend /
        // canReboot / canPowerOff. Those report false under `--test-mode`,
        // which would make the row invisible in exactly the preview used to
        // check it, and a greeter with no way to power the machine down is a
        // worse failure than a click that logind declines. The packaged themes
        // call these unguarded too.
        Repeater {
            model: [
                { label: "suspend",   action: "suspend"  },
                { label: "restart",   action: "reboot"   },
                { label: "shut down", action: "powerOff" }
            ]
            delegate: Text {
                renderType: Text.NativeRendering
                font.family: root.fontFamily
                font.pixelSize: root.statusFontSize
                color: powerArea.containsMouse ? root.cAccent : root.cSubtext0
                text: modelData.label

                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.action === "suspend") sddm.suspend()
                        else if (modelData.action === "reboot") sddm.reboot()
                        else sddm.powerOff()
                    }
                }
            }
        }
    }

    function attemptLogin() {
        // A check already in flight owns the field; a second sddm.login() would
        // be refused by the daemon anyway. See the `checking` note above.
        if (root.checking || passwordField.text.length === 0)
            return
        // THE FIELD IS NOT CLEARED HERE. hyprlock does empty its password
        // buffer on submit, but its dot row does not follow (see the freeze in
        // the dots Item), so what you typed stays on screen for the wait.
        // Leaving the text alone reproduces that without a second mechanism —
        // and it is `checking`, not an empty field, that stops a resubmit.
        // onLoginFailed() is what clears it, once there is a verdict.
        root.checking = true
        sddm.login(root.currentUser, passwordField.text, root.sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.checking = false
            root.failCount += 1
            // Clear the field FIRST: the assignment fires onTextChanged, which
            // blanks errorText. Setting the message before this would wipe it.
            passwordField.text = ""
            root.errorText = "Authentication failed"
            // forceActiveFocus, not `focus = true`: after a rejected password
            // the field must be ready to type into immediately, and `focus`
            // alone only sets focus within the scope, not the window's ACTIVE
            // focus, which is what receives key events.
            passwordField.forceActiveFocus()
        }
    }

    Component.onCompleted: passwordField.forceActiveFocus()
}

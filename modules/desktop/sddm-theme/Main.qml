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
    readonly property int margin: parseInt(config.Margin)

    // The username is never typed. SDDM records the last successful login in
    // /var/lib/sddm/state.conf and exposes it here; on a fresh install (no
    // state file yet) it is empty, so fall back to the first account rather
    // than presenting an unlabelled box.
    property string currentUser: userModel.lastUser !== ""
                                 ? userModel.lastUser
                                 : (userModel.count > 0
                                    ? userModel.data(userModel.index(0, 0), Qt.UserRole + 1)
                                    : "")
    property int sessionIndex: sessionModel.lastIndex
    property string errorText: ""
    property int failCount: 0

    // The pointer starts HIDDEN and appears on first real movement, matching
    // `hide_cursor = true` on the lock screen — with the difference that
    // hyprlock never brings its cursor back (Seat.cpp only calls onHover when
    // hide_cursor is unset), whereas this screen has a session menu and power
    // controls that have to stay reachable with a mouse.
    //
    // It matters more here than it sounds: the X server parks the pointer dead
    // centre at startup, which is inside the password field, so an always-on
    // cursor sits on top of the placeholder on every single boot.
    property bool pointerRevealed: false

    Rectangle {
        anchors.fill: parent
        color: root.cBase
        z: 0
    }

    // Owns the pointer for the WHOLE greeter surface, and watches it for the
    // first real movement. Two jobs in one place:
    //
    //  - It claims a cursor shape everywhere. Without that, any area where no
    //    QML item sets one shows the X ROOT window cursor instead, which SDDM
    //    only sets by shelling out to xsetroot (see ../sddm.nix) — so the shape
    //    would depend on that subprocess having worked.
    //  - It is what un-hides the pointer, because hover reaches it anywhere the
    //    item above has hoverEnabled off, which is everywhere except the two
    //    control rows in the bottom corners.
    //
    // z:0 and acceptedButtons: Qt.NoButton keep it inert otherwise: it sits
    // under every control and never swallows a click.
    MouseArea {
        anchors.fill: parent
        id: pointerWatch
        z: 0
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: root.pointerRevealed ? Qt.ArrowCursor : Qt.BlankCursor

        // First position seen is the parked one, not a movement, so it only
        // seeds the origin. The 5px threshold is hyprlock's own number — it
        // uses exactly that distance to tell a real move from jitter when
        // deciding whether to break out of its grace period (Seat.cpp).
        property real originX: -1
        property real originY: -1

        onPositionChanged: (mouse) => {
            if (originX < 0) {
                originX = mouse.x
                originY = mouse.y
                return
            }
            var dx = mouse.x - originX
            var dy = mouse.y - originY
            if (Math.sqrt(dx * dx + dy * dy) > 5)
                root.pointerRevealed = true
        }
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
    // Mirrors hyprlock's `label` blocks: time at font_size 90 anchored
    // -30,0 top-right, date at font_size 25 sitting 150px below it.
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
            font.pixelSize: parseInt(config.TimeSize)
            font.bold: true
            text: Qt.formatDateTime(new Date(), config.TimeFormat)
        }

        Text {
            id: dateLabel
            anchors.right: parent.right
            renderType: Text.NativeRendering
            color: root.cSubtext0
            font.family: root.fontFamily
            font.pixelSize: parseInt(config.DateSize)
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
        // that, so a 300x60 field with outline_thickness 4 occupies 308x68 on
        // screen. Qt insets a Rectangle's border instead, so the outer box has
        // to be grown by the outline on both sides to put the same number of
        // pixels in the same places. Measured: lock 308x68, greeter was 300x60.
        width: parseInt(config.FieldWidth) + 2 * parseInt(config.OutlineWidth)
        height: parseInt(config.FieldHeight) + 2 * parseInt(config.OutlineWidth)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        // hyprlock's `position = 0, -20` on a centre-aligned input-field, i.e.
        // 20px below the middle of the screen rather than dead centre.
        anchors.verticalCenterOffset: parseInt(config.FieldOffsetY)

        TextField {
            id: passwordField
            anchors.fill: parent
            focus: true
            echoMode: TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            selectByMouse: true
            selectionColor: root.cAccent
            renderType: Text.NativeRendering
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            font.family: root.fontFamily
            font.pixelSize: parseInt(config.FieldFontSize)

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
                border.width: parseInt(config.OutlineWidth)
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
            onTextChanged: root.errorText = ""
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
            anchors.fill: parent
            z: 2

            readonly property int size: parseInt(config.DotSize)
            readonly property int gap: parseInt(config.DotsSpacing)
            property real count: 0
            readonly property real rowWidth: (size + gap) * count - gap

            Behavior on count {
                NumberAnimation {
                    duration: parseInt(config.DotsAnimationMs)
                    easing.type: Easing.OutCubic
                }
            }

            Connections {
                target: passwordField
                function onTextChanged() { dots.count = passwordField.text.length }
            }

            Repeater {
                model: Math.ceil(dots.count)
                delegate: Rectangle {
                    width: dots.size
                    height: dots.size
                    radius: width / 2
                    color: root.cText
                    y: (dots.height - height) / 2
                    x: (dots.width - dots.rowWidth) / 2 + index * (dots.size + dots.gap)
                    // Only the newest dot is partially faded, exactly as
                    // hyprlock scales fontCol.a by (CURRDOTS - DOTFLOORED).
                    opacity: index === Math.floor(dots.count)
                             ? dots.count - Math.floor(dots.count)
                             : 1
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
        Text {
            anchors.centerIn: parent
            visible: passwordField.text.length === 0
            renderType: Text.NativeRendering
            textFormat: Text.StyledText
            font.family: root.fontFamily
            font.pixelSize: parseInt(config.FieldFontSize)
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
            // Never an I-beam: the parked pointer lands here, and a thin
            // vertical bar inside a password box is indistinguishable from a
            // text caret. Blank until the pointer is actually moved.
            cursorShape: root.pointerRevealed ? Qt.ArrowCursor : Qt.BlankCursor
            // hoverEnabled deliberately left off so hover still reaches the
            // root watcher above, which is what reveals the pointer.
        }
    }

    // --- status line under the field ----------------------------------------
    // Occupies the slot hyprlock gives $FAIL and $FPRINTPROMPT. Caps lock gets
    // priority because it is the likeliest cause of a rejected password.
    Text {
        z: 3
        anchors {
            top: parent.verticalCenter
            topMargin: parseInt(config.FieldHeight) + parseInt(config.FieldOffsetY)
            horizontalCenter: parent.horizontalCenter
        }
        renderType: Text.NativeRendering
        textFormat: Text.StyledText
        font.family: root.fontFamily
        font.pixelSize: parseInt(config.StatusFontSize)
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
        font.pixelSize: parseInt(config.StatusFontSize)
        color: sessionArea.containsMouse ? root.cAccent : root.cSubtext0
        text: sessionModel.data(sessionModel.index(root.sessionIndex, 0),
                                Qt.UserRole + 4) + " ▾"

        MouseArea {
            id: sessionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.pointerRevealed ? Qt.PointingHandCursor : Qt.BlankCursor
            onClicked: sessionMenu.open()
        }

        // Styled end to end. A bare QtQuick Controls Menu renders in the
        // default light palette — a white box with black text — which is
        // jarring against everything else here. Both the popup chrome and the
        // per-entry delegate have to be replaced to avoid that; setting only
        // the background leaves the item text and highlight stock.
        Menu {
            id: sessionMenu
            y: -height - 8
            padding: 6

            background: Rectangle {
                implicitWidth: 240
                color: root.cSurface0
                radius: 12          // the waybar/swaync corner
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
                    implicitHeight: 34

                    contentItem: Text {
                        text: sessionItem.text
                        renderType: Text.NativeRendering
                        font.family: root.fontFamily
                        font.pixelSize: parseInt(config.StatusFontSize)
                        color: sessionItem.highlighted ? root.cBase : root.cText
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                    }

                    background: Rectangle {
                        color: sessionItem.highlighted ? root.cAccent : "transparent"
                        radius: 8
                    }

                    onTriggered: root.sessionIndex = model.index
                }
            }
        }
    }

    // --- power actions, bottom-right ----------------------------------------
    Row {
        z: 3
        spacing: 16
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
                font.pixelSize: parseInt(config.StatusFontSize)
                color: powerArea.containsMouse ? root.cAccent : root.cSubtext0
                text: modelData.label

                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.pointerRevealed ? Qt.PointingHandCursor : Qt.BlankCursor
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
        if (passwordField.text.length === 0)
            return
        sddm.login(root.currentUser, passwordField.text, root.sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.failCount += 1
            // Clear the field FIRST: the assignment fires onTextChanged, which
            // blanks errorText. Setting the message before this would wipe it.
            passwordField.text = ""
            root.errorText = "Authentication failed"
            passwordField.focus = true
        }
    }

    Component.onCompleted: passwordField.forceActiveFocus()
}

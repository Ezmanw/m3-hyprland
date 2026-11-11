// Material 3 login screen for SDDM. Colours come from theme.conf / theme.conf.user.
import QtQuick 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.surface_container_low

    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string uiFont: "Google Sans Flex"
    property string iconFont: "Material Symbols Rounded"
    property real u: Math.max(1, height / 1080)   // scale with the screen

    function login() {
        message.text = ""
        sddm.login(userField.text, passField.text, root.sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            message.text = "Wrong password - try again"
            passField.text = ""
            passField.forceActiveFocus()
        }
    }

    // ---- clock ----
    Text {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.16
        color: config.primary
        font.family: root.uiFont
        font.weight: Font.Medium
        font.pixelSize: 150 * root.u
        text: Qt.formatTime(new Date(), "HH:mm")
    }
    Text {
        id: date
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clock.bottom
        color: config.on_surface_variant
        font.family: root.uiFont
        font.pixelSize: 28 * root.u
        text: Qt.formatDate(new Date(), "dddd d MMMM")
    }
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            clock.text = Qt.formatTime(new Date(), "HH:mm")
            date.text = Qt.formatDate(new Date(), "dddd d MMMM")
        }
    }

    // ---- sign-in card ----
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: date.bottom
        anchors.topMargin: 56 * root.u
        width: 420 * root.u
        height: column.height + 56 * root.u
        radius: 28 * root.u
        color: config.surface_container_high

        Column {
            id: column
            anchors.centerIn: parent
            width: parent.width - 56 * root.u
            spacing: 14 * root.u

            // user name
            Rectangle {
                width: parent.width; height: 56 * root.u; radius: height / 2
                color: config.surface_container_highest
                border.width: userField.activeFocus ? 2 : 0
                border.color: config.primary
                Text {
                    id: userIcon
                    anchors.verticalCenter: parent.verticalCenter
                    x: 18 * root.u
                    font.family: root.iconFont; font.pixelSize: 24 * root.u
                    color: config.on_surface_variant
                    text: ""   // person
                }
                TextInput {
                    id: userField
                    anchors.left: userIcon.right; anchors.leftMargin: 12 * root.u
                    anchors.right: parent.right; anchors.rightMargin: 20 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    color: config.on_surface
                    selectionColor: config.primary
                    selectedTextColor: config.on_primary
                    font.family: root.uiFont; font.pixelSize: 18 * root.u
                    text: userModel.lastUser
                    KeyNavigation.tab: passField
                    onAccepted: passField.forceActiveFocus()
                }
            }

            // password
            Rectangle {
                width: parent.width; height: 56 * root.u; radius: height / 2
                color: config.surface_container_highest
                border.width: passField.activeFocus ? 2 : 0
                border.color: config.primary
                Text {
                    id: lockIcon
                    anchors.verticalCenter: parent.verticalCenter
                    x: 18 * root.u
                    font.family: root.iconFont; font.pixelSize: 24 * root.u
                    color: config.on_surface_variant
                    text: ""   // lock
                }
                Text {
                    anchors.left: passField.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: passField.text.length === 0
                    color: config.on_surface_variant
                    font.family: root.uiFont; font.pixelSize: 18 * root.u
                    text: "Password"
                }
                TextInput {
                    id: passField
                    anchors.left: lockIcon.right; anchors.leftMargin: 12 * root.u
                    anchors.right: parent.right; anchors.rightMargin: 20 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    focus: true
                    echoMode: TextInput.Password
                    color: config.on_surface
                    selectionColor: config.primary
                    selectedTextColor: config.on_primary
                    font.family: root.uiFont; font.pixelSize: 18 * root.u
                    KeyNavigation.backtab: userField
                    onAccepted: root.login()
                }
            }

            Text {
                id: message
                width: parent.width
                visible: text.length > 0
                horizontalAlignment: Text.AlignHCenter
                color: config.error
                font.family: root.uiFont; font.pixelSize: 15 * root.u
                text: ""
            }

            // filled button
            Rectangle {
                width: parent.width; height: 56 * root.u; radius: height / 2
                color: loginArea.pressed ? config.primary_container : config.primary
                Text {
                    anchors.centerIn: parent
                    color: loginArea.pressed ? config.on_primary_container : config.on_primary
                    font.family: root.uiFont; font.weight: Font.Medium; font.pixelSize: 17 * root.u
                    text: "Sign in"
                }
                MouseArea { id: loginArea; anchors.fill: parent; onClicked: root.login() }
            }
        }
    }

    // ---- sessions: M3 chips ----
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: card.bottom
        anchors.topMargin: 24 * root.u
        spacing: 8 * root.u
        Repeater {
            model: sessionModel
            delegate: Rectangle {
                property bool selected: index === root.sessionIndex
                height: 36 * root.u
                width: chipText.implicitWidth + 32 * root.u
                radius: height / 2
                color: selected ? config.secondary_container : "transparent"
                border.width: selected ? 0 : 1
                border.color: config.outline
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    color: selected ? config.on_secondary_container : config.on_surface_variant
                    font.family: root.uiFont; font.pixelSize: 14 * root.u
                    text: model.name
                }
                MouseArea { anchors.fill: parent; onClicked: { root.sessionIndex = index; passField.forceActiveFocus() } }
            }
        }
    }

    // ---- power: tonal icon buttons ----
    Row {
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 28 * root.u
        spacing: 10 * root.u
        Repeater {
            model: [
                { icon: "", act: "suspend",  ok: sddm.canSuspend },
                { icon: "", act: "reboot",   ok: sddm.canReboot },
                { icon: "", act: "powerOff", ok: sddm.canPowerOff }
            ]
            delegate: Rectangle {
                visible: modelData.ok
                width: 52 * root.u; height: width; radius: width / 2
                color: area.containsMouse ? config.primary : config.primary_container
                Text {
                    anchors.centerIn: parent
                    font.family: root.iconFont; font.pixelSize: 26 * root.u
                    color: area.containsMouse ? config.on_primary : config.on_primary_container
                    text: modelData.icon
                }
                MouseArea {
                    id: area; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        if (modelData.act === "suspend") sddm.suspend()
                        else if (modelData.act === "reboot") sddm.reboot()
                        else sddm.powerOff()
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (userField.text.length === 0) userField.forceActiveFocus()
        else passField.forceActiveFocus()
    }
}

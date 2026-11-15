import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root

    implicitWidth: visibleActions.length > 0 ? contentCol.implicitWidth : 0
    implicitHeight: visibleActions.length > 0 ? (actionsRow.height + Math.max(12, Math.round(14 * root.centerScale)) + contentCol.spacing) : 0
    width: implicitWidth
    height: implicitHeight

    property bool isAuthenticating: false
    property real centerScale: 1.0
    property color clPrimary: "#c8c8c8"
    property color clSurfaceVariantFg: "#a0a0a0"

    property bool canSuspend: typeof sddm !== "undefined" ? Boolean(sddm.canSuspend) : true
    property bool canReboot: typeof sddm !== "undefined" ? Boolean(sddm.canReboot) : true
    property bool canShutdown: typeof sddm !== "undefined" ? Boolean(sddm.canPowerOff) : true
    property string currentSessionName: ""
    property bool hasMultipleSessions: false

    property string hoveredAction: ""
    property string hoveredLabel: ""

    signal cycleSessionRequested()
    signal actionTriggered(string action)

    readonly property var visibleActions: {
        var actions = [];

        if (root.canSuspend) {
            actions.push({
                actionId: "suspend",
                icon: "bedtime",
                label: qsTr("Sleep"),
                trigger: function() {
                    root.actionTriggered("suspend");
                    if (typeof sddm !== "undefined") sddm.suspend();
                }
            });
        }

        if (root.hasMultipleSessions) {
            actions.push({
                actionId: "session",
                icon: "desktop_windows",
                label: root.currentSessionName ? root.currentSessionName : qsTr("Switch Session"),
                trigger: function() { root.cycleSessionRequested(); }
            });
        }

        if (root.canReboot) {
            actions.push({
                actionId: "reboot",
                icon: "restart_alt",
                label: qsTr("Restart"),
                trigger: function() {
                    root.actionTriggered("reboot");
                    if (typeof sddm !== "undefined") sddm.reboot();
                }
            });
        }

        if (root.canShutdown) {
            actions.push({
                actionId: "shutdown",
                icon: "power_settings_new",
                label: qsTr("Shut Down"),
                trigger: function() {
                    root.actionTriggered("shutdown");
                    if (typeof sddm !== "undefined") sddm.powerOff();
                }
            });
        }

        return actions;
    }

    visible: visibleActions.length > 0

    Column {
        id: contentCol
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2 * root.centerScale

        Row {
            id: actionsRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6 * root.centerScale

            Repeater {
                model: root.visibleActions

                Item {
                    id: actionBtn
                    width: Math.max(26, Math.round(32 * root.centerScale))
                    height: width

                    readonly property var actionData: modelData
                    readonly property bool isHovered: btnMouse.containsMouse

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: actionBtn.isHovered ? Qt.rgba(root.clPrimary.r, root.clPrimary.g, root.clPrimary.b, 0.12) : "transparent"
                        scale: btnMouse.pressed ? 0.88 : actionBtn.isHovered ? 1.05 : 1.0

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: actionBtn.actionData.icon
                            font.family: LockScreenConfig.fontIcon
                            font.pixelSize: Math.max(16, Math.round(20 * root.centerScale))
                            color: actionBtn.isHovered ? root.clPrimary : root.clSurfaceVariantFg

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.hoveredAction = actionBtn.actionData.actionId;
                            root.hoveredLabel = actionBtn.actionData.label;
                        }
                        onExited: {
                            if (root.hoveredAction === actionBtn.actionData.actionId) {
                                root.hoveredAction = "";
                                root.hoveredLabel = "";
                            }
                        }
                        onClicked: actionBtn.actionData.trigger()
                    }
                }
            }
        }

        Item {
            id: labelContainer
            width: Math.max(actionsRow.width, 160 * root.centerScale)
            height: Math.max(12, Math.round(14 * root.centerScale))
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: root.hoveredLabel
                font.family: LockScreenConfig.fontBody
                font.pixelSize: Math.max(10, Math.round(12 * root.centerScale))
                color: root.clPrimary
                opacity: root.hoveredLabel.length > 0 ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
    }
}

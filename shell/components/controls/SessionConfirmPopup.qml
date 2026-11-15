pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.components.effects
import qs.services

Popup {
    id: root

    required property var tokens
    property string confirmTitle
    property string confirmMessage
    property string confirmText
    property bool destructive
    property list<string> pendingCommand: []
    property real maxMessageWidth: 320

    signal confirmed(list<string> command)

    function acceptConfirm(): void {
        const cmd = root.pendingCommand;
        root.close();
        root.confirmed(cmd);
    }

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    padding: root.tokens.padding.large

    onOpened: {
        cancelBtn.forceActiveFocus();
        Qt.callLater(() => {
            if (root.opened)
                cancelBtn.forceActiveFocus();
        });
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: root.tokens.anim.durations.expressiveDefaultEffects
            easing: root.tokens.anim.expressiveDefaultEffects
        }
        NumberAnimation {
            property: "scale"
            from: 0.88
            to: 1
            duration: root.tokens.anim.durations.expressiveFastSpatial
            easing: root.tokens.anim.expressiveFastSpatial
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: root.tokens.anim.durations.expressiveFastEffects
            easing: root.tokens.anim.expressiveFastEffects
        }
        NumberAnimation {
            property: "scale"
            from: 1
            to: 0.92
            duration: root.tokens.anim.durations.expressiveFastEffects
            easing: root.tokens.anim.expressiveFastEffects
        }
    }

    contentItem: ColumnLayout {
        spacing: root.tokens.spacing.medium

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab || event.key === Qt.Key_H || event.key === Qt.Key_L) {
                cancelBtn.forceActiveFocus();
                event.accepted = true;
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.maximumWidth: root.maxMessageWidth
            text: root.confirmTitle
            font: root.tokens.font.body.builders.large.weight(Font.Medium).build()
        }

        StyledText {
            Layout.fillWidth: true
            Layout.maximumWidth: root.maxMessageWidth
            text: root.confirmMessage
            color: Colours.palette.m3onSurfaceVariant
            font: root.tokens.font.body.small
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: root.tokens.spacing.small

            PopupButton {
                id: cancelBtn

                text: qsTr("Cancel")
                type: TextButton.Tonal
                focus: true
                oppositeButton: confirmBtn
                onClicked: root.close()
            }

            PopupButton {
                id: confirmBtn

                text: root.confirmText
                type: TextButton.Filled
                oppositeButton: cancelBtn
                inactiveColour: root.destructive ? Colours.palette.m3error : Colours.palette.m3primary
                inactiveOnColour: root.destructive ? Colours.palette.m3onError : Colours.palette.m3onPrimary
                activeColour: inactiveColour
                activeOnColour: inactiveOnColour
                onClicked: root.acceptConfirm()
            }
        }
    }

    background: Item {
        Elevation {
            anchors.fill: bgRect
            level: 3
            radius: bgRect.radius
        }

        StyledRect {
            id: bgRect

            anchors.fill: parent
            radius: root.tokens.rounding.large
            color: Colours.palette.m3surfaceContainerHigh
            border.width: 1
            border.color: Colours.palette.m3outlineVariant
        }
    }

    component PopupButton: TextButton {
        id: btn

        property Item oppositeButton: null

        activeFocusOnTab: true
        checked: btn.activeFocus
        internalChecked: btn.activeFocus

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Left:
            case Qt.Key_Right:
            case Qt.Key_Tab:
            case Qt.Key_Backtab:
            case Qt.Key_H:
            case Qt.Key_L:
                if (oppositeButton)
                    oppositeButton.forceActiveFocus();
                event.accepted = true;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                btn.clicked();
                event.accepted = true;
                break;
            case Qt.Key_Escape:
                root.close();
                event.accepted = true;
                break;
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: btn.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Colours.palette.m3onSurface
            visible: btn.activeFocus
            z: 2
        }
    }
}

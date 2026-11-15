pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> sessionGifItems: [
        MenuItem {
            icon: "cruelty_free"
            text: qsTr("Dino")
            value: "root:/assets/dino.gif"
        },
        MenuItem {
            icon: "animation"
            text: qsTr("Kuru Kuru")
            value: "root:/assets/kurukuru.gif"
        },
        MenuItem {
            icon: "pets"
            text: qsTr("Bongo Cat")
            value: "root:/assets/bongocat.gif"
        }
    ]

    function commandString(list: var): string {
        return (list || []).join(" ");
    }

    function commandList(text: string): var {
        return text.split(" ").filter(s => s.length > 0);
    }

    title: qsTr("Session")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enabled")
            subtext: qsTr("Show the session (power) menu")
            reset: ({ node: GlobalConfig.session, setting: "enabled" })
            checked: Config.session.enabled
            onToggled: GlobalConfig.session.enabled = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Vim keybinds")
            subtext: qsTr("Navigate the session menu with hjkl")
            reset: ({ node: GlobalConfig.session, setting: "vimKeybinds" })
            checked: Config.session.vimKeybinds
            onToggled: GlobalConfig.session.vimKeybinds = checked
        }

        StepperRow {
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels to drag before the menu moves")
            reset: ({ node: GlobalConfig.session, setting: "dragThreshold" })
            value: Config.session.dragThreshold
            from: 10
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.session.dragThreshold = v
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Show hibernate")
            subtext: qsTr("Display the Hibernate button in the session menu (turn off to disable)")
            reset: ({
                customGet: () => SessionOptions.showHibernate,
                customDef: true,
                customSet: v => SessionOptions.showHibernate = v
            })
            checked: SessionOptions.showHibernate
            onToggled: SessionOptions.showHibernate = checked
        }

        SelectRow {
            id: sessionGifSelect

            Layout.fillWidth: true
            label: qsTr("Session GIF")
            subtext: qsTr("Animated GIF shown in the session menu (%1)").arg((Config.paths.sessionGif || "root:/assets/dino.gif").split("/").pop())
            active: root.sessionGifItems.find(item => item.value === Config.paths.sessionGif) ?? null
            fallbackText: qsTr("Custom")
            fallbackIcon: "image"
            menuItems: root.sessionGifItems
            onSelected: item => {
                GlobalConfig.paths.sessionGif = item.value;
                GlobalConfig.save();
                active = Qt.binding(() => root.sessionGifItems.find(i => i.value === Config.paths.sessionGif) ?? null);
            }
        }

        NavRow {
            last: true
            Layout.fillWidth: true
            icon: "folder_open"
            label: qsTr("Custom session GIF")
            status: Config.paths.sessionGif ? Config.paths.sessionGif.split("/").pop() : qsTr("Default (dino.gif)")
            onClicked: sessionGifDialog.open()

            FileDialog {
                id: sessionGifDialog

                title: qsTr("Select Session GIF")
                filterLabel: qsTr("Images and GIFs (*.gif, *.webp, *.png, *.apng, *.jpg)")
                filters: ["gif", "webp", "png", "apng", "jpg", "jpeg"]
                onAccepted: path => {
                    GlobalConfig.paths.sessionGif = path;
                    GlobalConfig.save();
                    sessionGifSelect.active = Qt.binding(() => root.sessionGifItems.find(i => i.value === Config.paths.sessionGif) ?? null);
                }
            }
        }

        SectionHeader {
            text: qsTr("Icons")
        }

        LabeledField {
            first: true
            label: qsTr("Logout")
            value: Config.session.icons.logout
            onCommitted: v => GlobalConfig.session.icons.logout = v
        }

        LabeledField {
            label: qsTr("Shutdown")
            value: Config.session.icons.shutdown
            onCommitted: v => GlobalConfig.session.icons.shutdown = v
        }

        LabeledField {
            label: qsTr("Hibernate")
            value: Config.session.icons.hibernate
            onCommitted: v => GlobalConfig.session.icons.hibernate = v
        }

        LabeledField {
            last: true
            label: qsTr("Reboot")
            value: Config.session.icons.reboot
            onCommitted: v => GlobalConfig.session.icons.reboot = v
        }

        SectionHeader {
            text: qsTr("Commands")
        }

        LabeledField {
            first: true
            label: qsTr("Logout")
            value: root.commandString(Config.session.commands.logout)
            onCommitted: v => GlobalConfig.session.commands.logout = root.commandList(v)
        }

        LabeledField {
            label: qsTr("Shutdown")
            value: root.commandString(Config.session.commands.shutdown)
            onCommitted: v => GlobalConfig.session.commands.shutdown = root.commandList(v)
        }

        LabeledField {
            label: qsTr("Hibernate")
            value: root.commandString(Config.session.commands.hibernate)
            onCommitted: v => GlobalConfig.session.commands.hibernate = root.commandList(v)
        }

        LabeledField {
            last: true
            label: qsTr("Reboot")
            value: root.commandString(Config.session.commands.reboot)
            onCommitted: v => GlobalConfig.session.commands.reboot = root.commandList(v)
        }
    }

    component LabeledField: ConnectedRect {
        id: field

        property string label
        property string value

        signal committed(string v)

        Layout.fillWidth: true
        implicitHeight: row.implicitHeight + Tokens.padding.medium * 2

        RowLayout {
            id: row

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.medium

            StyledText {
                text: field.label
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurface
                Layout.preferredWidth: 128
            }
            StyledTextField {
                type: StyledTextField.Boxed
                Layout.fillWidth: true
                horizontalAlignment: TextInput.AlignLeft
                text: field.value
                onEditingFinished: field.committed(text)
            }
        }
    }
}

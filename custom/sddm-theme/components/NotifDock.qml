import QtQuick
import ".."
import QtQuick.Layouts

Rectangle {
    id: root

    property real centerScale: 1.0
    property bool isCaelestiaMode: false
    property color clSurfaceContainer: "#1c1c1c"
    property color clSurfaceContainerHigh: "#252525"
    property color clSurfaceContainerHighest: "#303030"
    property color clSecondaryContainer: "#2c2c2c"
    property color clSurfaceFg: "#e4e4e4"
    property color clSurfaceVariantFg: "#a0a0a0"
    property color clOutline: "#707070"

    property real cardRadius: 26
    radius: cardRadius
    color: clSurfaceContainer
    clip: true

    RowLayout {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16 * root.centerScale

        opacity: dinoLoader.isGameRunning ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 250 } }

        Text {
            Layout.fillWidth: true
            text: qsTr("Notifications")
            font { pixelSize: LockScreenConfig.sizeSmall; family: LockScreenConfig.fontBody; weight: Font.Medium }
            color: root.clOutline
            elide: Text.ElideRight
        }
    }

    Item {
        id: stackContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerRow.bottom
        anchors.bottom: parent.bottom

        Loader {
            id: dinoLoader
            z: 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16 * root.centerScale
            anchors.rightMargin: 16 * root.centerScale
            height: Math.min(200, stackContainer.height)

            active: true
            readonly property bool isGameRunning: item !== null && item.isPlaying === true

            sourceComponent: Item {
                readonly property bool isPlaying: dinoGame.isPlaying
                DinoGame {
                    id: dinoGame
                    anchors.centerIn: parent
                    width: dinoLoader.width
                    height: 200
                    activeColor: root.clSurfaceVariantFg
                    isCaelestiaMode: root.isCaelestiaMode
                }
            }
        }
    }
}

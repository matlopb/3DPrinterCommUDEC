import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Window {
    id: mainWindow

    width: 300
    height: 150
    visible: true
    color: "#ffffff"
    title: qsTr("Proceso en curso")

    Component.onCompleted: {
            x = Screen.width / 2 - width / 2
            y = Screen.height / 2 - height / 2
        }

    Column {
        spacing: 10
        anchors.centerIn: parent

        TextArea {
            id: loading

            text: qsTr("Espere mientras se completa el proceso")
        }

        ProgressBar {
            id: progressBar
            from: 0
            anchors.horizontalCenter: parent.horizontalCenter
        }

    }

    Connections {
        target: manager

        function onProgressChanged(progress) {
            progressBar.value = progress;
        }
        function onProgressTotalChanged(total) {
            progressBar.to = total;
        }

    }

}

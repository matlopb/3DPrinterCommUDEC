import QtQuick 2.15
import QtQuick.Controls //1.1
import QtQml 2.0
import QtQuick.Window 2.15

import UM 1.2 as UM
import Cura 1.0 as Cura

Window {
    id: messagedialog
    title: manager.get_message_title()
    width: {
        if (Qt.platform.os == "linux"){
            300 * screenScaleFactor
        }
        else if (Qt.platform.os == "windows"){
            350 * screenScaleFactor
        }
        else if (Qt.platform.os == "osx"){
            350 * screenScaleFactor
        }
    }
    height: {
        if (Qt.platform.os == "linux"){
            150 * screenScaleFactor
        }
        else if (Qt.platform.os == "windows"){
            150 * screenScaleFactor
        }
        else if (Qt.platform.os == "osx"){
            150 * screenScaleFactor
        }
    }
    minimumWidth: {
        if (Qt.platform.os == "linux"){
            300 * screenScaleFactor
        }
        else if (Qt.platform.os == "windows"){
            350 * screenScaleFactor
        }
        else if (Qt.platform.os == "osx"){
            350 * screenScaleFactor
        }
    }
    minimumHeight: {
        if (Qt.platform.os == "linux"){
            50 * screenScaleFactor
        }
        else if (Qt.platform.os == "windows"){
            50 * screenScaleFactor
        }
        else if (Qt.platform.os == "osx"){
            50 * screenScaleFactor
        }
    }

    Component.onCompleted: {
            x = Screen.width / 2 - width / 2
            y = Screen.height / 2 - height / 2
        }

    Rectangle {
        id: rectangle
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        color: "#ffffff"
        border.width: 1
        layer.enabled: false

        Image {
            id: message_image
            source: {
                if (manager.get_message_style() == "e"){
                    "./images/error.png"
                }
                else if (manager.get_message_style() == "i"){
                    "./images/complete.png"
                }
                else if (manager.get_message_style() == "r"){
                    "./images/warning.png"
                }
            }
            fillMode: Image.PreserveAspectFit;
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.right: message.left
            anchors.rightMargin: 5
            anchors.verticalCenter: message.verticalCenter
        }

        Text
        {
            id: message;
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 50
            anchors.top: parent.top
            anchors.topMargin: 20
            width: parent.width - 40
            wrapMode: Text.Wrap
            text: manager.get_message_content()
        }

        AnimatedImage{
            id: loading
            source: "images/loading.gif"
            width: 40
            anchors.top: message.bottom
            anchors.topMargin: 20
            anchors.horizontalCenter: okButton.horizontalCenter
            fillMode: AnimatedImage.PreserveAspectFit
            visible: (manager.get_message_style() == "r") ? true : false
        }

        Button
            {
                id: okButton;
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                width: 125
                height: 30
                visible: (manager.get_message_style() == "r") ? false : true

                Text
                {
                    anchors.centerIn: parent
                    width: contentWidth
                    height: contentHeight
                    font.bold: true;
                    font.pointSize: 10;
                    font.pixelSize: 17;                    
                    text: qsTr("Ok")
                }
                onClicked: messagedialog.close()
            }
    }

}

/*##^##
Designer {
    D{i:0;autoSize:true;height:480;width:640}
}
##^##*/

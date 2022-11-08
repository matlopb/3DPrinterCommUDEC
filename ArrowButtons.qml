import QtQuick.Layouts 1.3
import QtQuick 2.15
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.4

Item {
    property alias lowButton: xplus1
    property alias highButton: xplus10
    property int rotation: 0
    Button{
        id: xplus1

        width: 40
        height: 80
        style: ButtonStyle{
            label: Image {
                source: "./images/arrow.png";
                fillMode: Image.PreserveAspectFit;
                horizontalAlignment: Image.AlignLeft;
            }
        }
        Text {
            id: amount1
            text: qsTr("10")
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            font.bold: true
            transform: Rotation{origin.x: amount1.width/2; origin.y: amount1.height/2; angle: -rotation}
        }
    }
    Button{
        id: xplus10

        width: 66
        height: 80
        anchors.left: xplus1.right
        anchors.leftMargin: 10
        style: ButtonStyle{
            label: Image {
                source: "./images/doublearrow.png";
                fillMode: Image.PreserveAspectFit;
                horizontalAlignment: Image.AlignLeft;
            }
        }
        Text {
            id: amount10
            text: qsTr("100")
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            font.bold: true
            transform: Rotation{origin.x: amount10.width/2; origin.y: amount10.height/2; angle: -rotation}
        }
    }
}

import PyQt6.QtCore as QtCore
import PyQt6.QtGui as QtGui
import PyQt6.QtQuick as QtQuick
import PyQt6.QtQml as QtQml

from matplotlib.figure import Figure
from matplotlib.backends.backend_agg import FigureCanvasAgg

class MatplotlibImageProvider(QtQuick.QQuickImageProvider):
    figures = dict()

    def __init__(self):
        QtQuick.QQuickImageProvider.__init__(self, QtQml.QQmlImageProviderBase.ImageType.Image)

    def addFigure(self, name, **kwargs):
        figure = Figure(**kwargs)
        self.figures[name] = figure
        return figure

    def getFigure(self, name):
        return self.figures.get(name, None)

    def requestImage(self, p_str, size):
        figure = self.getFigure(p_str)
        if figure is None:
            return QtQuick.QQuickImageProvider.requestImage(self, p_str, size)

        canvas = FigureCanvasAgg(figure)
        canvas.draw()

        w, h = canvas.get_width_height()
        img = QtGui.QImage(canvas.buffer_rgba(), w, h, QtGui.QImage.Format.Format_RGBA8888).copy()

        return img, img.size()

import math
import multiprocessing
import os.path
import platform
from multiprocessing import Lock
from multiprocessing.sharedctypes import Array
from threading import Thread
from typing import List, cast
from functools import reduce
import random
import time
from datetime import datetime, timedelta

import sys
from pathlib import Path
import numpy as np

from UM.Application import Application
from UM.Extension import Extension
from UM.Logger import Logger
from UM.PluginRegistry import PluginRegistry
from UM.i18n import i18nCatalog
from cura.CuraApplication import CuraApplication
from .pycomm3.pycomm3 import LogixDriver
from .resources import MatplotlibImageProvider as matplt
from matplotlib import pyplot as plt

import os

from PyQt6.QtCore import pyqtSlot, QObject, pyqtSignal, QThread, QTimer, QPoint
import PyQt6.QtCore as QtCore
import PyQt6.QtGui as QtGui
import PyQt6.QtQuick as QtQuick
import PyQt6.QtQml as QtQml

i18n_catalog = i18nCatalog("PluginUDEC")  # Translates to a language Cura can read


def threaded(fn):
    def wrapper(*args, **kwargs):
        Thread(target=fn, args=args, kwargs=kwargs).start()
    return wrapper


class PluginUDEC(QObject, Extension):
    progress_changed = pyqtSignal(float, name="progressChanged")
    file_changed = pyqtSignal(str, name="fileChanged")
    progress_total_changed = pyqtSignal(float, name="progressTotalChanged")
    progress_end = pyqtSignal(name="progressEnd")
    connection_achieved = pyqtSignal(name="connectionAchieved")
    lock = Lock()
    end_flag = multiprocessing.Value('b', True)
    message_flag = multiprocessing.Value('b', False)

    def __init__(self) -> None:
        super().__init__()
        QObject.__init__(self)
        Extension.__init__(self)

        self.setMenuName(i18n_catalog.i18nc("@item:inmenu", "Plugin UDEC"))
        self.addMenuItem(i18n_catalog.i18nc("@item:inmenu", "Generar archivo RSLogix"), self.show_popup)
        self.addMenuItem(i18n_catalog.i18nc("@item:inmenu", "Conectar impresora"), self.show_connect)
        self._view = None
        self.connect_view = None
        self.message_view = None
        self.positions_list = []
        self.saved_values = []
        self.tag_dict = {}
        self.ip = ""
        self.loading_is_open = False
        self.plc = LogixDriver('192.168.1.18/2', init__program_tags=False)#'152.74.22.162/3', init__program_tags=False)
        self.imageProvider = matplt.MatplotlibImageProvider()
        self.plot_value_arrays = [[],[],[],[],[],[],[],[]]

    def plot(self, name, value_arrays, counter):
        #self.imageProvider = matplt.MatplotlibImageProvider()
        gain = 1.4
        figure = self.imageProvider.addFigure(name, figsize=(6.4*gain,4.8*gain))
        ax = figure.add_subplot()
        ax.grid(linewidth=2)
        ax.set(aspect='auto', ylim=[0,100], xlim=[self.bias_time(datetime.now(), 0, -1, 0), datetime.now()])
        ax.set_xlabel('Hora', fontsize=30)
        ax.set_ylabel('Valor', fontsize=30)
        ax.set_title("Visualización de variables", fontsize=30)
        ax.tick_params(axis='both', which='both', labelsize=15)

        for tag in range(len(value_arrays)):
            if counter[tag] < 59:
                X = np.array([self.bias_time(datetime.now(), 0, 0, -counter[tag] + i) for i in range(1+counter[tag])])
            else:
                X = np.array([self.bias_time(datetime.now(), 0, 0, -60 + i) for i in range(60)])
            Y = np.array(value_arrays[tag])
            ax.plot(X,Y, linewidth=3)

    def update_plots(self, values_list, tag_counters, tag_spot, upper_len, lower_len):
        # Grab values and put them in independant arrays. Separate arrays between upper and lower plot. Call self.plot to create the figure assossiated with the values.

        values = self.get_value_arrays(values_list, tag_spot)
        upper_value_arrays = []
        lower_value_arrays = []
        upper_counter = []
        lower_counter = []
        for i in range(upper_len):
            upper_value_arrays.append(values[i])
            upper_counter.append(tag_counters[i])
        for i in range(lower_len):
            lower_value_arrays.append(values[i + upper_len])
            lower_counter.append(tag_counters[i + upper_len])
        self.plot('plot_one', upper_value_arrays, upper_counter)
        self.plot('plot_two', lower_value_arrays, lower_counter)
        return

    def get_value_arrays(self, values, tag_spot):

        _values = []
        for i in range(len(values)):
            self.plot_value_arrays[tag_spot[i]].append(values[i])#values[tag_spot[i]])
            if len(self.plot_value_arrays[tag_spot[i]]) > 60:
                self.plot_value_arrays[tag_spot[i]].pop(0)
            _values.append(self.plot_value_arrays[tag_spot[i]])
        for element in self.plot_value_arrays:
            if self.plot_value_arrays.index(element) not in tag_spot:
                element.clear()
        return _values

    @pyqtSlot(list, list, list,  int, int, result=list)
    def update_series(self, tag_list, tag_counters, tag_spot, upper_len, lower_len) -> List[float]:
        """Reads the values of the tags in tag_list from the device associated with
        the given IP address"""

        try:
            tag_names = self.extract_names(tag_list)
            n_tags = len(tag_names)
            if not self.plc.connected:
                self.plc.open()
            tag_read = self.plc.read(*tag_names)
            values = self.extract_values(tag_read, n_tags)
            self.saved_values = values
            if self.loading_is_open:
                self.connection_achieved.emit()
                self.loading_is_open = False
        except:
            if not self.loading_is_open:
                self.set_message_params('r', 'Se produjo un error',
                                        'Se ha perdido la conexion con la impresora. '
                                        '\nReconectando...')
                self.progress_end.emit()
            self.loading_is_open = True            
            values = self.saved_values
        self.update_plots(values, tag_counters, tag_spot, upper_len, lower_len)
        return values

    def bias_time(self, original_time, hr_bias, min_bias, sec_bias):
        """Recieves a datetime-time object and modifies it with the given bias for hr, min and sec."""

        new_time = original_time + timedelta (hours=hr_bias) + timedelta (minutes=min_bias) + timedelta (seconds=sec_bias)
        return new_time

    def shift_elements(self, arr, num, fill_value):
        result = np.empty_like(arr)
        if num > 0:
            result[:num] = fill_value
            result[num:] = arr[:-num]
        elif num < 0:
            result[num:] = fill_value
            result[:num] = arr[-num:]
        else:
            result[:] = arr
        return result

    @pyqtSlot()
    def clear_all_arrays(self):

        for element in self.plot_value_arrays:
            element.clear()

    @pyqtSlot(int)
    def clear_series(self, index):

        self.plot_value_arrays[index].clear()

    @pyqtSlot(str, result=list)
    def plc_tag_list(self, ip) -> List[str]:
        """Gets the list of program tagsand returns a list containing the names of all tags
        with less than 100 elements"""

        self.ip = ip
        plc = LogixDriver(ip, init__program_tags=True)
        plc.open()
        tag_list = plc.get_tag_list('Program:MainProgram').copy()
        tag_name_list = self.get_names(self.get_tags_info(tag_list))
        plc.close()
        return tag_name_list

    def get_names(self, tag_list) -> List[str]:
        tag_name_list = []
        element_number = 0
        tags_info_dict = tag_list

        for name in tags_info_dict:
            tag_elements_name = self.get_tag_elements(name.replace("Program:MainProgram.",''), tags_info_dict[name][1])
            for element in tag_elements_name:
                tag_name_list.append(element)
                self.tag_dict[element] = [element_number, tags_info_dict[name][0], tags_info_dict[name][2]]
                element_number += 1
            element_number = 0
        return tag_name_list

    def get_tags_info(self, tag_list) -> dict:
        tags_info_list = reduce(self.fetch_info, tag_list, dict())
        return tags_info_list

    def fetch_info(self, acc_dict, cur_dict) -> dict:
        tag_name = cur_dict["tag_name"].replace("Program:Program:MainProgram.","Program:MainProgram.")
        tag_dim = cur_dict["dimensions"]
        tag_n_dim = cur_dict["dim"]
        tag_total_elements = self.count_elements(tag_dim)
        if tag_total_elements < 100:
            acc_dict[tag_name] = [tag_total_elements, tag_dim, tag_n_dim]
        return acc_dict

    def count_elements(self, dimensions) -> float:
        total_elements = 1
        dim_copy = dimensions.copy()
        for axis_value in dim_copy:
            if axis_value == 0:
                dimensions.remove(0)
            else:
                total_elements *= axis_value
        return total_elements

    def get_tag_elements(self, tag_name, tag_dim) -> List[str]:
        length = len(tag_dim)
        tag_list = []
        if length == 0:
            tag_list.append(tag_name)
        elif length == 1:
            for i in range(tag_dim[0]):
                tag_list.append(tag_name+"["+str(i)+"]")
        elif length == 2:
            for i in range(tag_dim[0]):
                for j in range(tag_dim[1]):
                    tag_list.append(tag_name+"["+str(i)+","+str(j)+"]")
        elif length == 3:
            for i in range(tag_dim[0]):
                for j in range(tag_dim[1]):
                    for k in range(tag_dim[2]):
                        tag_list.append(tag_name+"["+str(i)+"]"+"["+str(j)+"]"+"["+str(k)+"]")
        return tag_list

    def extract_names(self, tag_list) -> List:
        tag_names = []
        for tag in tag_list:
            tag_name = tag.split('[')[0]
            tag_dim = self.tag_dict[tag][1]
            tag_n_dim = self.tag_dict[tag][2]
            if tag_dim == 1:
                tag_names.append('Program:MainProgram.' + tag_name)
            elif tag_n_dim == 2:
                tag_names.append('Program:MainProgram.' + tag)
            else:
                tag_element = self.tag_dict[tag][0]
                tag_names.append('Program:MainProgram.' + tag_name + "["+str(tag_element)+"]")
        return tag_names

    def extract_values(self, tag_list, number_of_elements) -> List:
        values = []
        if number_of_elements > 1:
            for element in tag_list:
                tag_value = element.value
                if tag_value is True:
                    tag_value = 1
                elif tag_value is False:
                    tag_value = 0
                values.append(tag_value)
        else:
            tag_value = tag_list.value
            if tag_value is True:
                tag_value = 1
            elif tag_value is False:
                tag_value = 0
            values.append(tag_value)
        return values    

    @pyqtSlot(str)
    def save_value(self, ip):
        with LogixDriver(ip) as plc:
            self.new_value = plc.read('Program:MainProgram.array_tag{3}').value[0]

    def show_connect(self):
        """Displays an error message with the given title and message"""
        #self.plot('plot_one')
        #self.plot('plot_two')
        self.create_view("Connect.qml")
        if self.connect_view is None:
            Logger.log("e", "Not creating Connect window since the QML component failed to be created.")
            return
        self.connect_view.show()

    @pyqtSlot(str, result=list)
    def plc_info(self, ip) -> List[str]:
        try:
            print(self.plc.connected)
            if not self.plc.connected:
                self.plc.open()
            is_connected = self.plc.connected
            print(is_connected)
            product_name = self.plc.info["product_name"]
            print(product_name)
            name = self.plc.info["name"]
            print(name)
            programs = ""
            for program in list(self.plc.info["programs"].keys()):
                programs += str(program)
            print(program)
            return [product_name, name, programs, is_connected]
        except:
            self.set_message_params('e', 'Se produjo un error',
                                    'Se ha producido un error de conexion. '
                                    'Por favor revise que la direccion IP sea '
                                    'la correcta.')
            self.progress_end.emit()
            return ["-----------", "-----------", "-----------", False]

    @pyqtSlot()
    def send_instructions(self):
        n_instructions = len(self.positions_list)
        if not self.plc.connected:
            self.plc.open()
        is_printing = self.plc.read('Program:MainProgram.sw_beginapp').value
        print('Program:MainProgram.Matriz_L{'+str(n_instructions)+'}')
        if self.plc.connected and not is_printing:
            self.plc.write('Program:MainProgram.Matriz_L{'+str(n_instructions)+'}',   # ARREGLAR LA SOBRESCRITURA DEL LARGO DE INSTRUCCIONES AL EJECUTAR MOVIMIENTO ANTES DE ENVIAR INSTRUCCIONES
                      self.positions_list)
            self.plc.write('Program:MainProgram.total_coordinates', self.total_coordinates)
            self.set_message_params('i', 'Operacion finalizada',
                                    'Las instrucciones fueron enviadas a la '
                                    'impresora. Puede monitorear el proceso en '
                                    'las pantallas adyacentes.')
        else:
            self.set_message_params('e', 'Operacion cancelada',
                                    'La impresora se encuentra trabajando. '
                                    'Detenga la impresion en la pestaña "Control" '
                                    'o espere a que finalice.')
        self.progress_end.emit()

    @pyqtSlot(float, float, float, float, float, float)
    def generate_instructions_list(self, sb, sp, arm_length, height, ws_radio, ws_height):
        """Responsible for using the given parameters to call the functions which calculate the instructions."""

        params = [sb, sp, arm_length, height, ws_radio, ws_height]
        self.params = params
        if not self.are_valid(params):
            Logger.log("e", "Some parameters ")
            self.progress_end.emit()
            return
        coordinates = self.get_coordinates(self.split_lines(self.get_gcode()))
        print('PROCESS IS DONE')
        self.total_coordinates = len(coordinates)
        print('PROCESS IS DONE')
        if self.fits_in_ws(ws_radio, ws_height, coordinates):
            print('PROCESS IS DONE')
            ws_coordinates = self.z_bias(coordinates, float(height), float(ws_height))
            try:
                self.inv_kin_problem(ws_coordinates, params)
                self.positions_list = self.flatten(self.positions_list)
            except ValueError:
                self.set_message_params('e', 'Se produjo un error',
                                        'Se ha producido un error de calculo. '
                                        '0Por favor revise que los datos de '
                                        'impresora esten correctos.')
                self.progress_end.emit()
                return
            self.set_message_params('i', 'Operacion finalizada',
                                    'Finalizo la generacion de instrucciones. '
                                    'Puede enviarlas a la impresora una vez '
                                    'realizada la conexion.')
            self.progress_end.emit()


    def flatten(self, list) -> List:
        flattened_list = [item for sublist in list for item in sublist]
        return flattened_list

    @pyqtSlot(result=bool)
    def look_for_gcode(self):
        scene = Application.getInstance().getController().getScene()
        if not hasattr(scene, "gcode_dict"):
            Logger.warning("no gcode in system")
            return False
        return True

    def get_list_names(self, tag_list) -> List[str]:
        tag_names = []
        for tag in tag_list:
            tag_name = tag.split('[')[0]
            tag_dim = self.tag_dict[tag][1]
            tag_n_dim = self.tag_dict[tag][2]
            if tag_dim == 1:
                tag_names.append('Program:MainProgram.' + tag_name)
            elif tag_n_dim == 2:
                tag_names.append('Program:MainProgram.' + tag)
            else:
                tag_element = self.tag_dict[tag][0]
                tag_names.append('Program:MainProgram.' + tag_name + "["+str(tag_element)+"]")

    def extract_tag_name(self, tag) -> str:
        tag_name = tag.split('[')[0]
        tag_dim = self.tag_dict[tag][1]
        tag_n_dim = self.tag_dict[tag][2]
        if tag_dim == 1:
            extracted_name = 'Program:MainProgram.' + tag_name
        elif tag_n_dim == 2:
            extracted_name = 'Program:MainProgram.' + tag
        else:
            tag_element = self.tag_dict[tag][0]
            extracted_name = 'Program:MainProgram.' + tag_name + "["+str(tag_element)+"]"
        return extracted_name

    @pyqtSlot(str, float)
    def write_value(self, tag_name, new_value):
        tag_valid_name = self.extract_tag_name(tag_name)
        if not self.plc.connected:
            self.plc.open()
        #with LogixDriver(self.ip) as plc:
        self.plc.write(tag_valid_name, new_value)

    @pyqtSlot(str, str, float)
    def tune_gain(self, tag, switch, gain_value):
        self.write_value(tag, gain_value)
        self.write_value(switch, 1)

    @pyqtSlot(result=list)
    def get_progress_percentage(self):
        try:
            step = self.plc.read('i').value
            self.prev_step = step
            if self.loading_is_open:
                self.connection_achieved.emit()
                self.loading_is_open = False
        except:
            if not self.loading_is_open:
                self.set_message_params('r', 'Se produjo un error',
                                        'Se ha perdido la conexion con la impresora. '
                                        '\nReconectando...')
                self.progress_end.emit()
            self.loading_is_open = True
            step = self.prev_step
        percentage = 100*step/self.total_coordinates
        if percentage >= 100:
            self.set_message_params('i', 'Fin del proceso',
                                    'Ha finalizado la impresion de la figura. ')
            self.progress_end.emit()
        progress = [int(percentage), step]
        return progress

    @pyqtSlot(result=bool)
    def switch_printing(self):
        self.check_servos()
        if not self.plc.connected:
            self.plc.open()
        read_state = self.plc.read('Program:MainProgram.sw_beginapp').value
        if read_state:
            self.plc.write('Program:MainProgram.sw_beginapp', 0)
            return False
        else:
            self.plc.write('Program:MainProgram.sw_beginapp', 1)
            return True

    @pyqtSlot()
    def check_servos(self):
        if not self.plc.connected:
            self.plc.open()
        servos_are_active = self.plc.read('Actuador_B1.ServoActionStatus').value
        printing_done = self.plc.read('Program:MainProgram.sw_is_printing_done').value
        if not servos_are_active:
            self.plc.write('Program:MainProgram.sw_start_servos', 1)
            self.plc.write('Program:MainProgram.sw_init_var', 1)
        if printing_done and servos_are_active:
            self.plc.write('Program:MainProgram.sw_init_var', 1)

    @pyqtSlot(result=str)
    def get_n_coor(self):
        return str(self.total_coordinates)

    @pyqtSlot(result=list)
    def get_actual_position(self):
        tags = ['Actuador_B1.ActualPosition', 'Actuador_B2.ActualPosition', 'Actuador_B3.ActualPosition']
        with LogixDriver(self.ip, init__program_tags=False) as plc:
            position_info = plc.read(*tags)
        positions = self.extract_values(position_info, 3)
        positions = [round(value) for value in positions]
        return positions

    @pyqtSlot(float, float, float)
    def move_to(self, x_pos, y_pos, z_pos):
        print(x_pos, y_pos, z_pos)
        servo_pos = self.inv_kin_problem([[x_pos, y_pos, z_pos - self.params[3] + self.params[5], 6000]], self.params)
        print(servo_pos)
        is_printing = self.plc.read('Program:MainProgram.sw_beginapp').value
        is_homing = self.plc.read('sw_startposition').value
        if self.plc.connected and not is_printing and not is_homing:
            self.plc.write('Program:MainProgram.coor_move_array{3}', self.flatten(servo_pos)) # coor_move_array{3}
            self.plc.write('Program:MainProgram.sw_coor_move', 1)
        else:
            self.set_message_params('e', 'Operacion cancelada',
                                    'La impresora se encuentra trabajando. '
                                    'Detenga la impresion en la pestaña "Control" '
                                    'o espere a que finalice.')
            self.progress_end.emit()

    @pyqtSlot()
    def run_home(self):
        with LogixDriver(self.ip, init__program_tags=False) as plc:
            is_printing = self.plc.read('Program:MainProgram.is_printing').value
            is_moving = plc.read('Program:MainProgram.sw_coor_move').value
            is_printer_busy = is_moving or is_printing
            if not is_printer_busy:
                plc.write('sw_startposition', 1)
            else:
                self.set_message_params('e', 'Operacion cancelada',
                                        'La impresora se encuentra trabajando. '
                                        'Detenga la impresion en la pestaña "Control" '
                                        'o espere a que finalice el movimiento.')
                self.progress_end.emit()

    @pyqtSlot()
    def stop_printing(self):
        if not self.plc.connected:
            self.plc.open()
        is_done_printing = self.plc.read('Program:MainProgram.sw_is_printing_done').value
        is_homing = self.plc.read('sw_startposition').value
        step = self.plc.read('i').value
        if step != 0 and not is_done_printing and not is_homing:
            self.plc.write('Program:MainProgram.sw_stop_printing', 1)
        elif is_homing:
            self.set_message_params('e', 'Operacion cancelada',
                                    'La impresora se encuentra en proceso de homing.')
            self.progress_end.emit()
        else:
            self.set_message_params('e', 'Operacion cancelada',
                                    'La impresora no se encuentra trabajando.')
            self.progress_end.emit()

    @pyqtSlot()
    def force_stop(self):
        if not self.plc.connected:
            self.plc.open()
        self.plc.write('Program:MainProgram.sw_off_servos', 1)

    @pyqtSlot(result=list)
    def get_gains(self):
        if not self.plc.connected:
            self.plc.open()
        gains_list = self.plc.read('Program:MainProgram.SV_gains{6}').value
        return gains_list

    @pyqtSlot(float)
    def tune_speed(self, quotient):
        self.write_value('move_speed_gain', quotient/100)


# ----------------------------------------------------------------------------------------------------

# -----------------------------------------------------------------------------------------------------

    @pyqtSlot(str)
    def start_worker(self, path):
        QTimer.singleShot(0, lambda: self.worker.run(path))

    @pyqtSlot(result=str)
    def showGcode(self) -> str:
        """Shows the available gcode (if any) on the corresponding zone."""

        gcode = self.get_gcode_bit()
        if len(gcode) < 20:
            return ''.join(gcode)
        gcode = self.split_lines(gcode)
        gcode_string = ' '.join(gcode)
        return gcode_string

    @threaded
    def generatePositionsAsync(self, sb, sp, arm_length, height, ws_radio, ws_height, file_path,
                               overwrite, destination_path=None, dir_path=None) -> None:
        """Responsible for using the given parameters to call the functions which calculate the instructions and
        then write them in a L5K file."""

        params = [sb, sp, arm_length, height, ws_radio, ws_height]
        print(str(params))
        file_params = [file_path, overwrite, destination_path, dir_path]
        if self.are_valid(params, file_params) is False:
            self.progress_end.emit()
            self.end_flag.value = False
            return
        coordinates = self.get_coordinates(self.split_lines(self.get_gcode()))
        if self.fits_in_ws(ws_radio, ws_height, coordinates):
            ws_coordinates = self.z_bias(coordinates, float(height), float(ws_height))
            try:
                self.inv_kin_problem(ws_coordinates, params)
            except ValueError:
                self.set_message_params('e', 'Se produjo un error', 'Se ha producido un error de calculo. Por favor '
                                                                    'revise que los datos de impresora esten '
                                                                    'correctos.')
                self.progress_end.emit()
                self.end_flag.value = False
                return
            self.generateInstructions(file_path, overwrite, self.positions_list, destination_path)
            self.end_flag.value = False
            self.set_message_params('i', 'Operacion finalizada', 'Se termino la generacion de instrucciones. Las '
                                                                 'instrucciones fueron guardadas en el archivo '
                                                                 'indicado.')
            self.progress_end.emit()

    @pyqtSlot(float, float, float, float, float, float, str, bool, str, str)
    def generatePositions(self, sb, sp, arm_length, height, ws_radio, ws_height, file_path, overwrite,
                          destination_path=None, dir_path=None) -> None:
        """Called when the user presses the 'generate instructions' button. Responsible for using the given parameters
         to call the functions which calculate the instructions and then write them in a L5K file."""

        self.generatePositionsAsync(sb, sp, arm_length, height, ws_radio, ws_height, file_path,
                                    overwrite, destination_path, dir_path)

    def are_valid(self, params, file_params=None) -> bool:
        print("EN PROCESO DE VALIDACION")
        if 0 in params:
            self.set_message_params('e', 'Faltan datos', 'Ingrese todos los datos solicitados e intente otra vez.')
            return False
        if file_params is not None:
            if file_params[1]:
                if not os.path.isfile(self.get_url(file_params[0])):
                    print("no existe archivo")
                    self.set_message_params('e', 'Archivo inexistente',
                                            'El archivo indicado no es compatible o no existe.\nPor favor seleccione un '
                                            'archivo valido.')
                    return False
            if not file_params[1]:
                if not os.path.isfile(self.get_url(file_params[0])):
                    self.set_message_params('e', 'Archivo inexistente',
                                            'El archivo indicado no es compatible o no existe.\nPor favor seleccione un '
                                            'archivo valido.')
                    return False
                elif os.path.isfile(self.get_url(file_params[2])):
                    self.set_message_params('e', 'Archivo ya existe',
                                            'El archivo ya existe.\nPor favor escoja otro nombre.')
                    return False
                elif not os.path.exists(self.get_url(file_params[3])):
                    self.set_message_params('e', 'Carpeta inexistente',
                                            'La carpeta indicada no existe.\nPor favor seleccione un directorio valido.')
                    return False
        return True

    def fits_in_ws(self, radio, height, coordinates) -> bool:
        """Checks if the given coordinates fit in the working space"""

        for element in coordinates:
            if abs(element[0]) > radio or abs(element[1]) > radio or abs(element[2]) > height:
                print(element[0], radio, abs(element[1]), radio, abs(element[2]), height)
                self.set_message_params('e', 'Coordenadas incompatibles',
                                        'La figura revanada es mas grande que '
                                        'el espacio de trabajo disponible.')
                self.progress_end.emit()
                return False
        return True

    def z_bias(self, coordinates, height, ws_height) -> List[List[float]]:
        """Returns the given coordinates with an added bias on the Z axis. This bias depends on the specified RDL
        height """

        for i in range(len(coordinates)):
            coordinates[i][2] *= -1
            coordinates[i][2] -= height - ws_height
        return coordinates

    def inv_kin_problem(self, coordinates, parameters):
        """Returns the positions of the motors for each given coordinate"""

        self.positions_list.clear()

        sb = parameters[0]
        sp = parameters[1]
        wb = (math.sqrt(3)/6)*sb
        wp = (math.sqrt(3)/6)*sp
        ub = (math.sqrt(3)/3)*sb
        up = (math.sqrt(3)/3)*sp
        l = parameters[2]

        a = (sb - sp) / 2
        b = wb - wp
        c = up - ub
        x = self.get_column(coordinates, 0)
        y = self.get_column(coordinates, 1)
        z = self.get_column(coordinates, 2)
        feed_rate = self.get_column(coordinates, 3)
        print(x, y, z)
        self.progress_total_changed.emit(len(coordinates))
        for i in range(len(coordinates)):
            C1 = x[i] ** 2 + y[i] ** 2 + z[i] ** 2 + a ** 2 + b ** 2 + 2 * a * x[i] + 2 * b * y[i] - l ** 2
            C2 = x[i] ** 2 + y[i] ** 2 + z[i] ** 2 + a ** 2 + b ** 2 - 2 * a * x[i] + 2 * b * y[i] - l ** 2
            C3 = x[i] ** 2 + y[i] ** 2 + z[i] ** 2 + c ** 2 + 2 * c * y[i] - l ** 2
            L1 = -z[i] - math.sqrt(z[i] ** 2 - C1)
            L2 = -z[i] - math.sqrt(z[i] ** 2 - C2)
            L3 = -z[i] - math.sqrt(z[i] ** 2 - C3)
            self.positions_list.append([round(L1, 3), round(L2, 3), round(L3, 3), feed_rate[i]/60])
            self.progress_changed.emit(i+1)
        new_list = self.positions_list
        return new_list

    def get_column(self, coordinates, column) -> List[float]:
        """Returns the specified column from the given List"""

        axis = []
        for i in range(len(coordinates)):
            axis.append(coordinates[i][column])
        return axis

    def split_lines(self, base_text) -> List[str]:
        """Splits the given text into lines and saves them onto a list. Returns the list."""

        lines = [""]
        line_list = [""]
        for line in base_text:
            lines += line
            if self.match_inline(['\n'])(line):
                line_list.append(''.join(lines))
                lines = [""]
        return line_list

    def match_text(self, base_text, find) -> List[str]:
        """Reads a given text and stores its content up until a match is found. Returns stored content."""

        content = [""]
        for line in base_text:
            content[0] += line
            if self.match_inline([find])(line):
                break
        return content

    def get_gcode_bit(self) -> List[str]:
        """Gets the available gcode (if any) from the Cura build plate."""

        scene = Application.getInstance().getController().getScene()
        if not hasattr(scene, "gcode_dict"):
            Logger.warning("no gcode in system")
            return ["No gcode in system"]
        gcode_dict = getattr(scene, "gcode_dict")
        if not gcode_dict:
            Logger.log("e", "no gcode in system")
            return ["No gcode in system"]
        active_build_plate_id = CuraApplication.getInstance().getMultiBuildPlateModel().activeBuildPlate
        gcode_list = gcode_dict[active_build_plate_id]
        return str(gcode_list[1])

    def get_gcode(self) -> List[str]:
        """Gets the available gcode (if any) from the Cura build plate."""

        scene = Application.getInstance().getController().getScene()
        if not hasattr(scene, "gcode_dict"):
            Logger.log("e", "no gcode in system")
            return ["No gcode in system"]
        gcode_dict = getattr(scene, "gcode_dict")
        if not gcode_dict:
            Logger.log("e", "no gcode in system")
            return ["No gcode in system"]
        active_build_plate_id = CuraApplication.getInstance().getMultiBuildPlateModel().activeBuildPlate
        gcode_list = gcode_dict[active_build_plate_id]
        gcodeList = [""]
        for i in range(len(gcode_list)):
            gcodeList += str(gcode_list[i])
        return gcodeList

    def get_coordinates(self, gcode) -> List[List[float]]:
        """Gets the XYZ coordinates and feed rate speed from the G code and
        stores them in a list of lists."""

        filtered_lines = list(filter(self.match_inline([' X', ' Y', ' Z']), gcode))
        coordinates = []
        x_axis = 1
        y_axis = 1
        z_axis = 1
        feed_rate = 60
        for line in filtered_lines:
            words = line.split()
            #if self.match_inline(['M84'])(line):
            #    continue
            if self.match_inline(['X'])(line):                
                x_axis = self.get_values('X', words)
            if self.match_inline(['Y'])(line):
                y_axis = self.get_values('Y', words)
            if self.match_inline(['Z'])(line):
                z_axis = self.get_values('Z', words)
            if self.match_inline(['F'])(line):
                feed_rate = self.get_values('F', words)
            coordinates.append([x_axis, y_axis, z_axis, feed_rate])
        Logger.log('i', "The number of coordinates is " + str(len(coordinates)))
        return coordinates

    def get_values(self, axis, line) -> float:
        """Returns the values of the coordinates from the G code"""

        axis_values = list(filter(self.match_inline([axis]), line))
        axis_values = self.to_int(axis_values)
        return axis_values

    def to_int(self, word) -> float:
        """Returns the value in the given word as a float"""

        value = list(filter(self.is_int, list(word[0])))        
        value = ''.join(value)
        if value is '':
            value = 100
        value = float(value)
        return value

    def is_int(self, element) -> bool:
        """Returns true if the element holds a number representing a component of a coordinate"""

        if 'X' in element or 'Y' in element or 'Z' in element or 'F' in element:
            return False
        else:
            return True

    def get_url(self, url) -> str:
        """get the real URL for the selected file"""

        if platform.system() == 'Windows':
            fileUrl = self.get_os_path(url, '')
            return fileUrl
        fileUrl = self.get_os_path(url, '/')
        return fileUrl

    def get_os_path(self, url, separator) -> str:
        tmp = [separator]
        for i in range(len(url)):
            if i > 7:
                tmp[0] += str(url[i])
        file_path = ''.join(tmp)
        return file_path

    @pyqtSlot(str, result=str)
    def showFileContent(self, url) -> str:
        """Show the content of the selected file in the bottom right text box."""

        file = open(self.get_url(url), mode='r', encoding='utf-8')
        content = file.read()
        file.close()
        return content

    def write_file(self, file_path, destination_path, positions, action) -> None:
        """Copies the content of file_path in destination_path while adding extra content"""

        file = open(self.get_url(file_path), mode='r', encoding='utf-8')
        file_read = file.readlines()
        text = self.get_matrix(positions)
        with open(self.get_url(destination_path), action, encoding='utf-8') as file_write:
            for line in file_read:
                file_write.write(line)
                if self.match_inline(['\t\t\tTAG'])(line):
                    file_write.write(str(text) + '\n')
        file.close()

    def get_matrix(self, positions) -> str:
        """Returns the given positions formatted as a RSLogix 5000 matrix TAG"""

        L: str = '\t\t\t\tMatriz_L : REAL[' + str(
            len(positions)) + ',4](Description := "matriz de posiciones",' + '\n'
        L += '\t\t\t\t            RADIX := Float) := ['
        for i in range(0, len(positions), 2):
            try:
                if i is not 0:
                    L += '						,'
                L += ''.join(str(positions[i][0])) + ',' + ''.join(str(positions[i][1])) + ',' + ''.join(
                    str(positions[i][2])) + ',' + ''.join(str(positions[i][3])) + ',' + ''.join(str(positions[i + 1][0])) + ',' + ''.join(
                    str(positions[i + 1][1])) + ',' + ''.join(str(positions[i + 1][2])) + ',' + ''.join(str(positions[i + 1][3])) + '\n'
            except IndexError:
                L += ''.join(str(positions[i][0])) + ',' + ''.join(str(positions[i][1])) + ',' + ''.join(
                    str(positions[i][2])) + '\n'
        L += '						]' + ';'
        return L

    def generateInstructions(self, file_path, overwrite, positions, destination_path=None) -> None:
        """Generates the instructions by either overwriting the base file or creating a new one."""

        if overwrite:
            self.write_file(file_path, file_path, positions, 'w')
        if not overwrite:
            self.write_file(file_path, destination_path, positions, 'x')

    def match_inline(self, find):
        """Looks for a match between 2 strings"""

        def find_word(line) -> bool:

            for i in range(len(find)):
                if find[i] in line:
                    return True
            return False

        return find_word
############################# quiza puedo acceder al qml engine a travez de CuraApplication
    def create_view(self, view) -> None:
        """Creates the view to be used."""

        Logger.log("d", "Creating requested view.")
        path = os.path.join(cast(str, PluginRegistry.getInstance().getPluginPath("UDECPlugin")), view)
        if view == "main.qml":
            self._view = CuraApplication.getInstance().createQmlComponent(path, {"manager": self})
            print("-----------------------", self._view.contentItem)
            if self._view is None:
                Logger.log("e",
                           "Not creating Plugin UDEC window since the view variable is empty.")
                return
            Logger.log("d", "Plugin UDEC view created.")

        if view == "MessageDialog.qml":
            print("SE ESTA CREANDO LA VENTANA DE MENSAJES")
            self.message_view = CuraApplication.getInstance().createQmlComponent(path, {"manager": self})
            print("SE ASIGNO LA VENTANA A LA VARIABLE MESSAGE VIEW")
            if self.message_view is None:
                Logger.log("e",
                           "Not creating message window since the message view variable is empty.")
                return
            Logger.log("d", "Message view created.")

        if view == "Connect.qml":
            CuraApplication.getInstance()._qml_engine.addImageProvider('perflog', self.imageProvider)
            self.connect_view = CuraApplication.getInstance().createQmlComponent(path, {"manager": self})
            if self.connect_view is None:
                Logger.log("e",
                           "Not creating Connect window since the message view variable is empty.")
                return
            Logger.log("d", "Connect view created.")            

    def show_popup(self) -> None:
        """Show the GUI of the UDEC Plugin."""

        self.create_view("main.qml")
        if self._view is None:
            Logger.log("e", "Not creating Plugin UDEC window since the QML component failed to be created.")
            return
        self._view.show()

    @pyqtSlot(result=str)
    def get_message_title(self) -> str:
        title = str(self.message_title)
        return title

    @pyqtSlot(result=str)
    def get_message_content(self) -> str:
        content = str(self.message_content)
        return content

    @pyqtSlot(result=str)
    def get_message_style(self) -> str:
        style = str(self.message_style)
        return style

    @pyqtSlot(str, str, str)
    def set_message_params(self, style, title, content) -> None:
        #self.message_style.value = style#.encode(encoding = 'utf-8') #bytes(style, 'utf-8')
        #self.message_title.value = title#.encode(encoding = 'utf-8') #bytes(title, 'utf-8')
        #self.message_content.value = content#.encode(encoding = 'utf-8') #bytes(content, 'utf-8')
        self.message_style = style#.encode(encoding = 'utf-8') #bytes(style, 'utf-8')
        self.message_title = title#.encode(encoding = 'utf-8') #bytes(title, 'utf-8')
        self.message_content = content#.encode(encoding = 'utf-8') #bytes(content, 'utf-8')

    @pyqtSlot()
    def show_message(self) -> None:
        """Displays an error message with the given title and message"""

        self.create_view("MessageDialog.qml")
        if self.message_view is None:
            Logger.log("e", "Not creating message window since the QML component failed to be created.")
            return
        self.message_view.show()

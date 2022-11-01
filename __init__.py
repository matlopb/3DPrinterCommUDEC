from . import PluginUDEC

from UM.i18n import i18nCatalog
i18n_catalog = i18nCatalog("PluginUDEC")

def getMetaData():
	return{}
	
def register(app):
    return {"extension":PluginUDEC.PluginUDEC()}

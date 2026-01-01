from typing import ClassVar, Union
from datetime import datetime
import logging
import hashlib

from marshmallow import fields, Schema

from nl.oppleo.models.Base import Base, DbSession
from nl.oppleo.exceptions.Exceptions import DbException

from sqlalchemy import orm, Column, String, Boolean, DateTime
from sqlalchemy.exc import InvalidRequestError

from nl.oppleo.config.OppleoSystemConfig import OppleoSystemConfig

oppleoSystemConfig = OppleoSystemConfig()

"""
# Alternatively, catch reload events
from sqlalchemy.events import event

@event.listens_for(RfidModel, 'load')
def RfidModel_load(target, context):
    print('RfidModel load')

@event.listens_for(RfidModel, 'refresh')
def RfidModel_refresh(target, context, attrs):
    print('RfidModel refresh')
"""

class RfidModel(Base):
    __logger: ClassVar[logging.Logger] = logging.getLogger(f"{__name__}.{__qualname__}")
    __tablename__ = 'rfid'
    
    rfid = Column(String(100), primary_key=True)
    enabled = Column(Boolean)
    created_at = Column(DateTime)
    last_used_at = Column(DateTime)
    name = Column(String(100))
    valid_from = Column(DateTime)
    valid_until = Column(DateTime)

    vehicle_make = Column(String(100))
    vehicle_model = Column(String(100))
    license_plate = Column(String(20))
    vehicle_name = Column(String(100))
    vehicle_vin = Column(String(100))

    api_account = Column(String(256))
    get_odometer = Column(Boolean)


    def __init__(self):
        self.__logger.setLevel(level=oppleoSystemConfig.getLogLevelForModule(self.__class__.__module__))    


    # sqlalchemy calls __new__ not __init__ on reconstructing from database. Decorator to call this method
    @orm.reconstructor   
    def init_on_load(self):
        # Make sure the init does not reset any values, those are taken from the db
        self.__init__()


    def set(self, data):
        for key in data:
            setattr(self, key, data.get(key))
        self.allow = data.get('allow', False)
        self.created_at = data.get('created_at', datetime.now())
        self.modified_at = data.get('last_used_at', datetime.now())


    """
        Call when vehicle api connection is broken
    """
    def cleanupVehicleInfo(self):
        self.__logger.debug("cleanupVehicleInfo()")
        self.api_account = None
        self.get_odometer = False
        """
            Keep
            - make
            - model
            - vin
            - license plate
        """
        self.save()


    def save(self):
        try:
            with DbSession() as db_session:
                db_session.add(self)
                db_session.commit()
        except InvalidRequestError as e:
            self.__logger.error("Could not save to {} table in database".format(self.__tablename__ ), exc_info=True)
        except Exception as e:
            self.__logger.error("Could not save to {} table in database".format(self.__tablename__ ), exc_info=True)
            raise DbException("Could not save to {} table in database".format(self.__tablename__ ))


    def update(self):
        try:
            with DbSession() as db_session:
                db_session.commit()
        except InvalidRequestError as e:
            self.__logger.error("Could not commit (update) to {} table in database".format(self.__tablename__ ), exc_info=True)
        except Exception as e:
            self.__logger.error("Could not commit (update) to {} table in database".format(self.__tablename__ ), exc_info=True)
            raise DbException("Could not commit (update) to {} table in database".format(self.__tablename__ ))


    def delete(self):
        try:
            with DbSession() as db_session:
                db_session.delete(self)
                db_session.commit()
        except InvalidRequestError as e:
            self.__logger.error("Could not delete from {} table in database".format(self.__tablename__ ), exc_info=True)
        except Exception as e:
            self.__logger.error("Could not delete from {} table in database".format(self.__tablename__ ), exc_info=True)
            raise DbException("Could not delete from {} table in database".format(self.__tablename__ ))


    def hasValidToken(self):
        self.__logger.debug("hasValidToken()")
        from nl.oppleo.api.VehicleApi import VehicleApi
        try:
            vApi = VehicleApi(rfid_model=self)
        except Exception as e:
            # TODO: capture unauthorized 
            pass
        if vApi.isAuthorized():
            return True
        # Not (no longer) authorized
        self.cleanupVehicleInfo()
        return False


    def getVehicleFilename(self, rfid:str=None, account:str=None, vin:str=None):
        if rfid is None:
            rfid = self.rfid
        if rfid is None:
            return 'unknown.png'

        if account is None:
            account = self.api_account
        if account is None:
            return 'unknown.png'

        if vin is None:
            vin = self.vehicle_vin
        if vin is None:
            return 'unknown.png'

        return hashlib.md5( bytes( rfid + account + vin, 'utf-8') ).hexdigest() + '.png'


    @staticmethod
    def get_all():
        try:
            with DbSession() as db_session:
                rfidm = db_session.query(RfidModel) \
                                  .all()
                for rfid_model in rfidm:
                    db_session.expunge(rfid_model)
            return rfidm
        except InvalidRequestError as e:
            RfidModel.__logger.error("Could not query from table {} in database".format(RfidModel.__tablename__), exc_info=True)
        except Exception as e:
            # Nothing to roll back
            RfidModel.__logger.error("Could not query from table {} in database".format(RfidModel.__tablename__), exc_info=True)
            raise DbException("Could not query from {} table in database".format(RfidModel.__tablename__ ))
  

    @staticmethod
    def get_one(rfid):
        try:
            with DbSession() as db_session:
                rfidm = db_session.query(RfidModel) \
                                .filter(RfidModel.rfid == str(rfid)) \
                                .first()
                db_session.expunge(rfidm)
                return rfidm
        except InvalidRequestError as e:
            RfidModel.__logger.error("Could not query from {} table in database".format(RfidModel.__tablename__ ), exc_info=True)
        except Exception as e:
            # Nothing to roll back
            RfidModel.__logger.error("Could not query from {} table in database".format(RfidModel.__tablename__ ), exc_info=True)
            raise DbException("Could not query from {} table in database".format(RfidModel.__tablename__ ))

    def __repr(self):
        return '<id {}>'.format(self.rfid)

    def to_str(self):
        return ({
                "rfid": str(self.rfid),
                "enabled": self.enabled,
                "created_at": (str(self.created_at.strftime("%d/%m/%Y, %H:%M:%S")) if self.created_at is not None else ''),
                "last_used_at": (str(self.last_used_at.strftime("%d/%m/%Y, %H:%M:%S")) if self.last_used_at is not None else ''),
                "name": '' if self.name is None else str(self.name),
                "vehicle_make": '' if self.vehicle_make is None else str(self.vehicle_make),
                "vehicle_model": '' if self.vehicle_model is None else str(self.vehicle_model),
                "get_odometer": str(self.get_odometer),
                "license_plate": '' if self.license_plate is None else str(self.license_plate),
                "valid_from": (str(self.valid_from.strftime("%d/%m/%Y, %H:%M:%S")) if self.valid_from is not None else None),
                "valid_until": (str(self.valid_until.strftime("%d/%m/%Y, %H:%M:%S")) if self.valid_until is not None else None),
                "api_account": '' if self.api_account is None else str(self.api_account),
                "vehicle_name": '' if self.vehicle_name is None else str(self.vehicle_name),
                "vehicle_vin": '' if self.vehicle_vin is None else str(self.vehicle_vin)
            })

    def to_dict(self):
        return ({
                "rfid": self.rfid,
                "enabled": self.enabled,
                "created_at": (str(self.created_at.strftime("%d/%m/%Y, %H:%M:%S")) if self.created_at is not None else ''),
                "last_used_at": (str(self.last_used_at.strftime("%d/%m/%Y, %H:%M:%S")) if self.last_used_at is not None else None),
                "name": '' if self.name is None else str(self.name),
                "vehicle_make": '' if self.vehicle_make is None else str(self.vehicle_make),
                "vehicle_model": '' if self.vehicle_model is None else str(self.vehicle_model),
                "get_odometer": self.get_odometer,
                "license_plate": '' if self.license_plate is None else str(self.license_plate),
                "valid_from": (str(self.valid_from.strftime("%d/%m/%Y, %H:%M:%S")) if self.valid_from is not None else None),
                "valid_until": (str(self.valid_until.strftime("%d/%m/%Y, %H:%M:%S")) if self.valid_until is not None else None),
                "api_account": '' if self.api_account is None else str(self.api_account),
                "vehicle_name": '' if self.vehicle_name is None else str(self.vehicle_name),
                "vehicle_vin": '' if self.vehicle_vin is None else str(self.vehicle_vin)
            })



class RfidSchema(Schema):
    """
    Rfid Schema
    """
    rfid = fields.Str(required=True)
    enabled = fields.Bool(dump_only=True)
    created_at = fields.DateTime(dump_only=True)
    last_used_at = fields.DateTime(dump_only=True)
    name = fields.Str(required=True)
    vehicle_make = fields.Str(required=True)
    vehicle_model = fields.Str(required=True)
    get_odometer = fields.Bool(dump_only=True)
    license_plate = fields.Str(required=True)
    valid_from = fields.DateTime(dump_only=True)
    valid_until = fields.DateTime(dump_only=True)
    api_account = fields.Str(required=True)
    vehicle_name = fields.Str(required=True)
    vehicle_vin = fields.Str(required=True)


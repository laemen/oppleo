from typing import ClassVar, Union
import logging
from marshmallow import fields, Schema

from nl.oppleo.models.Base import Base, DbSession
from nl.oppleo.exceptions.Exceptions import DbException

from sqlalchemy import orm, func, Column, String, Integer, Boolean, Float, desc
from sqlalchemy.exc import InvalidRequestError
from sqlalchemy.orm.session import make_transient

from nl.oppleo.config.OppleoSystemConfig import OppleoSystemConfig

oppleoSystemConfig = OppleoSystemConfig()

class EnergyDeviceModel(Base):
    """
    EnergyDevice Model
    """
    __logger: ClassVar[logging.Logger] = logging.getLogger(f"{__name__}.{__qualname__}")

    # table name
    __tablename__ = 'energy_device'

    energy_device_id = Column(String(100), primary_key=True)
    port_name = Column(String(100))
    slave_address = Column(Integer)
    baudrate = Column(Integer)
    bytesize = Column(Integer)
    parity = Column(String(1))
    stopbits = Column(Integer)
    serial_timeout = Column(Float)
    simulate = Column(Boolean)
    mode = Column(String(10))
    close_port_after_each_call = Column(Boolean)
    modbus_config = Column(String(100))
    device_enabled = Column(Boolean)

    def __init__(self, data):
        self.__logger.setLevel(level=oppleoSystemConfig.getLogLevelForModule(self.__class__.__module__))  


    # sqlalchemy calls __new__ not __init__ on reconstructing from database. Decorator to call this method
    @orm.reconstructor   
    def init_on_load(self):
        pass


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

    """
    @staticmethod
    def get():
        try:
            with DbSession() as db_session:
                edm =  db_session.query(EnergyDeviceModel) \
                                .order_by(desc(EnergyDeviceModel.energy_device_id)) \
                                .first()
                return edm
        except InvalidRequestError as e:
            EnergyDeviceModel.__logger.error("Could not get energy device from table {} in database ({})".format(EnergyDeviceModel.__tablename__, str(e)), exc_info=True)
        except Exception as e:
            # Nothing to roll back
            EnergyDeviceModel.__logger.error("Could not get energy device from table {} in database ({})".format(EnergyDeviceModel.__tablename__, str(e)), exc_info=True)
            raise DbException("Could not get energy device from table {} in database ({})".format(EnergyDeviceModel.__tablename__, str(e)))
    """
        
    # Can only delete not-used
    def delete(self):
        try:
            with DbSession() as db_session:
                db_session.delete(self)
                db_session.commit()
        except Exception as e:
            self.__logger.error("Could not delete from {} table in database".format(self.__tablename__ ), exc_info=True)


    """
    @staticmethod
    def get():
        try:
            with DbSession() as db_session:        
                edm =  db_session.query(EnergyDeviceModel) \
                                .order_by(desc(EnergyDeviceModel.energy_device_id)) \
                                .first()
                return edm
        except InvalidRequestError as e:
            EnergyDeviceModel.__logger.error("Could not get energy device from table {} in database ({})".format(EnergyDeviceModel.__tablename__, str(e)), exc_info=True)
        except Exception as e:
            # Nothing to roll back
            EnergyDeviceModel.__logger.error("Could not get energy device from table {} in database ({})".format(EnergyDeviceModel.__tablename__, str(e)), exc_info=True)
            raise DbException("Could not get energy device from table {} in database ({})".format(EnergyDeviceModel.__tablename__, str(e)))
    """

    @staticmethod
    def get(energy_device_id:str|None=None):
        try:
            with DbSession() as db_session:
                if energy_device_id is None:
                    edm =  db_session.query(EnergyDeviceModel) \
                                    .order_by(desc(EnergyDeviceModel.energy_device_id)) \
                                    .first()
                else:
                    edm =  db_session.query(EnergyDeviceModel) \
                                    .filter(EnergyDeviceModel.energy_device_id == energy_device_id)    \
                                    .order_by(desc(EnergyDeviceModel.energy_device_id)) \
                                    .first()
                db_session.expunge(edm)
                return edm
        except InvalidRequestError as e:
            EnergyDeviceModel.__logger.error("Could not get energy device from table {} in database ({})".format(EnergyDeviceModel.__tablename__, str(e)), exc_info=True)
        except Exception as e:
            # Nothing to roll back
            EnergyDeviceModel.__logger.error("Could not get energy device from table {} in database ({})".format(EnergyDeviceModel.__tablename__, str(e)), exc_info=True)
            raise DbException("Could not get energy device from table {} in database ({})".format(EnergyDeviceModel.__tablename__, str(e)))

    def duplicate(self, newEnergyDeviceId:str=None):
        try:
            with DbSession() as db_session:
                # expunge the object from session
                db_session.expunge(self)
                # http://docs.sqlalchemy.org/en/rel_1_1/orm/session_api.html#sqlalchemy.orm.session.make_transient
                make_transient(self)  
                self.energy_device_id = newEnergyDeviceId
                db_session.add(self)
                db_session.commit()
                return self
        except InvalidRequestError as e:
            EnergyDeviceModel.__logger.error("Could not duplicate energy device {} to {} in table {} in database ({})".format(self.energy_device_id, newEnergyDeviceId, self.__tablename__, str(e)), exc_info=True)
        except Exception as e:
            # Nothing to roll back
            EnergyDeviceModel.__logger.error("Could not duplicate energy device {} to {} in table {} in database ({})".format(self.energy_device_id, newEnergyDeviceId, self.__tablename__, str(e)), exc_info=True)
            raise DbException("Could not duplicate energy device {} to {} in table {} in database ({})".format(self.energy_device_id, newEnergyDeviceId, self.__tablename__, str(e)))

    def __repr(self):
        return '<id {}>'.format(self.id)

    def get_count(self, q):
        count = 0
        try:
            count_q = q.statement.with_only_columns(func.count()).order_by(None)
            count = q.session.execute(count_q).scalar()
        except Exception as e:
            self.__logger.error("Could not query from {} table in database".format(self.__tablename__ ), exc_info=True)
            raise DbException("Could not query from {} table in database".format(self.__tablename__ ))
        return count


class EnergyDeviceSchema(Schema):
    """
    Energy Device Schema
    """
    energy_device_id = fields.Str(required=True)
    port_name = fields.Str(dump_only=True)
    slave_address = fields.Int(dump_only=True)
    baudrate = fields.Int(dump_only=True)
    bytesize = fields.Int(dump_only=True)
    parity = fields.Str(dump_only=True)
    stopbits = fields.Int(dump_only=True)
    serial_timeout = fields.Float(dump_only=True)
    simulate = fields.Bool(dump_only=True)
    mode = fields.Str(dump_only=True)
    close_port_after_each_call = fields.Bool(dump_only=True)
    modbus_config = fields.Str(dump_only=True)
    device_enabled = fields.Bool(dump_only=True)


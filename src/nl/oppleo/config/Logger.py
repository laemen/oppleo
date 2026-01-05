import logging
from logging.handlers import RotatingFileHandler
import os
import sys

def init_log_X(process_name, log_file, daemons=None, loglevel=logging.WARNING, maxBytes=524288, backupCount=5):
    logger_process = logging.getLogger(process_name)
    logger_package = logging.getLogger('nl.oppleo')
    logger_process.setLevel(loglevel)
    logger_package.setLevel(loglevel)

    daemons = [] if daemons is None else daemons

    # Create formatter with timestamp
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(process)d %(processName)s - %(thread)d %(threadName)s - %(levelname)s - %(message)s'
    )

    # Create rotating file handler
    try:
        rfHandler = RotatingFileHandler(log_file, maxBytes=maxBytes, backupCount=backupCount)
    except PermissionError:
        log_file = os.path.join(os.path.dirname(os.path.realpath(__file__)).split('src/nl/oppleo/config')[0], 'Oppleo.log')
        rfHandler = RotatingFileHandler(log_file, maxBytes=maxBytes, backupCount=backupCount)
    
    rfHandler.setLevel(loglevel)
    rfHandler.setFormatter(formatter)

    # Create console handler
    ch = logging.StreamHandler()
    ch.setLevel(loglevel)
    ch.setFormatter(formatter)

    # Add handlers to loggers
    for logger in [logger_process, logger_package]:
        logger.addHandler(rfHandler)
        logger.addHandler(ch)

    # Add handlers to daemon loggers
    for daemon in daemons:
        logger_daemon = logging.getLogger(daemon)
        logger_daemon.setLevel(loglevel)
        logger_daemon.addHandler(rfHandler)
        logger_daemon.addHandler(ch)

    # Redirect stdout and stderr to log file
    class StreamToLogger:
        def __init__(self, logger, level=logging.INFO):
            self.logger = logger
            self.level = level
            self.buffer = ''

        def write(self, message):
            message = message.rstrip()
            if message:
                self.logger.log(self.level, message)

        def flush(self):
            pass

    sys.stdout = StreamToLogger(logger_process, logging.INFO)
    sys.stderr = StreamToLogger(logger_process, logging.ERROR)

    return logger_process



def init_log(process_name, log_file, daemons=None, loglevel=logging.WARNING, maxBytes=524288, backupCount=5):
    logger_process = logging.getLogger(process_name)
    logger_package = logging.getLogger('nl.oppleo')
    logger_process.setLevel(loglevel)
    logger_package.setLevel(loglevel)

    daemons = [] if daemons is None else daemons

    # create file handler which logs even debug messages
    try:
        fh = logging.FileHandler(log_file)
    except PermissionError as pe:
        # So this location is  not allowed. Fall back to the Oppleo directory
        log_file = os.path.join(os.path.dirname(os.path.realpath(__file__)).split('src/nl/oppleo/config')[0], 'Oppleo.log')
        fh = logging.FileHandler(log_file)
    fh.setLevel(loglevel)

    # create console handler with a higher log level
    ch = logging.StreamHandler()
    ch.setLevel(loglevel)
    # create formatter and add it to the handlers
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(process)d %(processName)s - %(thread)d %(threadName)s - %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)

    # Add the log message handler to the logger
    rfHandler = logging.handlers.RotatingFileHandler(
                    log_file, 
                    maxBytes=maxBytes,          # max bytes per file 
                    backupCount=backupCount     # 5 backup files, 6 in total
                )
    rfHandler.setFormatter(formatter)

    # add the handlers to the logger
    logger_process.addHandler(fh)
    logger_process.addHandler(ch)
    logger_process.addHandler(rfHandler)
    logger_package.addHandler(fh)
    logger_package.addHandler(ch)
    logger_package.addHandler(rfHandler)

    for daemon in daemons:
        logger_daemon = logging.getLogger(daemon)
        logger_daemon.setLevel(loglevel)
        logger_daemon.addHandler(fh)
        logger_daemon.addHandler(ch)
        logger_daemon.addHandler(rfHandler)

    # Redirect stdout to logfile
    log_file = open(log_file, "a")

    # sys.stdout = log_file

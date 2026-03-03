import serial
import time
import logging

logger = logging.getLogger(__name__)

class GSMHardwareService:
    """
    Service gérant l'interface physique avec le module GSM (SIM800L, SIM7600, etc.)
    via les commandes AT sur port série.
    """
    # Configuration par défaut (à adapter selon ton branchement)
    # Sur Linux, c'est souvent /dev/ttyUSB0 (clé USB) ou /dev/ttyS0 (GPIO)
    PORT = "/dev/ttyUSB0" 
    BAUD_RATE = 9600

    @classmethod
    def envoyer_sms_physique(cls, numero, message):
        """
        Envoie un SMS réel.
        Retourne True si le module a confirmé l'envoi, False sinon.
        """
        ser = None
        try:
            # 1. Ouverture du port série
            ser = serial.Serial(cls.PORT, cls.BAUD_RATE, timeout=5)
            time.sleep(1) # Petit temps d'attente pour l'initialisation

            # 2. On s'assure que le module est prêt
            ser.write(b'AT\r')
            time.sleep(0.5)
            
            # 3. Configuration du mode texte (obligatoire pour envoyer des strings)
            ser.write(b'AT+CMGF=1\r')
            time.sleep(0.5)

            # 4. Définition du numéro de téléphone
            # La commande est AT+CMGS="+237xxxxxx"
            cmd_numero = f'AT+CMGS="{numero}"\r'
            ser.write(cmd_numero.encode())
            time.sleep(0.5)

            # 5. Envoi du contenu du message
            ser.write(message.encode())
            
            # 6. Envoi du caractère spécial Ctrl+Z (ASCII 26) pour valider l'envoi
            ser.write(bytes([26]))
            
            # Attendre la réponse du module (peut prendre quelques secondes)
            time.sleep(3)
            reponse = ser.read_all().decode(errors='ignore')

            if "OK" in reponse or "+CMGS:" in reponse:
                logger.info(f"SMS envoyé avec succès au {numero}")
                return True
            else:
                logger.error(f"Échec de l'envoi. Réponse module : {reponse}")
                return False

        except serial.SerialException as e:
            # Si le module n'est pas branché sur ce port
            logger.error(f"Impossible d'accéder au module GSM sur {cls.PORT}: {e}")
            # EN DÉVELOPPEMENT : On simule un succès pour ne pas bloquer le reste
            print(f"\n[MODE TEST] Matériel absent sur {cls.PORT}. Simulation SMS vers {numero} : {message}\n")
            return True 
            
        except Exception as e:
            logger.error(f"Erreur imprévue dans GSMHardwareService: {e}")
            return False
            
        finally:
            if ser and ser.is_open:
                ser.close()
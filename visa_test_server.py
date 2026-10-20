import asyncio
import struct
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# RPC / VXI-11 Protocol Constants
RPC_PROGRAM_PORTMAP = 100000
RPC_PROGRAM_VXI11   = 100063
VXI11_CORE_PORT     = 1025

class PurePythonVxi11Mock:
    def __init__(self, host="127.0.0.1"):
        self.host = host

    def _parse_rpc_record(self, data: bytes):
        """Extracts raw RPC payload fragments by handling the 4-byte fragment header."""
        if len(data) < 4:
            return None, data
        frag_header = struct.unpack(">I", data[:4])[0]
        is_last = bool(frag_header & 0x80000000)
        frag_len = frag_header & 0x7FFFFFFF
        
        if len(data) < 4 + frag_len:
            return None, data # Fragment incomplete
        return data[4:4+frag_len], data[4+frag_len:]

    async def handle_portmapper(self, reader, writer):
        """Simulates Port 111 rpcbind daemon. Directs NI-VISA to our VXI-11 core port."""
        try:
            data = await reader.read(4096)
            payload, _ = self._parse_rpc_record(data)
            if not payload or len(payload) < 24:
                return

            # Unpack XID and Message Type from standard ONC/RPC Header
            xid, msg_type, rpc_vers, program, version, proc = struct.unpack(">IIIIII", payload[:24])
            
            # Proc 3 represents PMAPPROC_GETPORT (Ask where a service is hosted)
            if program == RPC_PROGRAM_PORTMAP and proc == 3:
                req_prog, req_vers, req_proto, req_port = struct.unpack(">IIII", payload[24:40])
                
                if req_prog == RPC_PROGRAM_VXI11:
                    logger.info(f"[PORTMAP] Client requested VXI-11 Core (100063) port resolution.")
                    
                    # Construct ONC/RPC Reply Payload Header
                    reply_payload = struct.pack(">IIIIII", 
                        xid, 
                        1, # MSG_REPLY
                        0, # MSG_ACCEPTED
                        0, # AUTH_NULL
                        0, # Descriptor size
                        0  # SUCCESS
                    )
                    # Append the actual destination port back to NI-VISA
                    reply_payload += struct.pack(">I", VXI11_CORE_PORT)
                    
                    # Prepend the mandatory 4-byte RPC Record Marking fragment envelope
                    frag_header = struct.pack(">I", len(reply_payload) | 0x80000000)
                    writer.write(frag_header + reply_payload)
                    await writer.drain()
        except Exception as e:
            logger.error(f"Portmapper fault entry: {e}")
        finally:
            writer.close()

    async def handle_vxi11_core(self, reader, writer):
        """Simulates Port 1025 VXI-11 device Core communication channel."""
        peer = writer.get_extra_info('peername')
        logger.info(f"[VXI11 CORE] Connection established with active driver instance: {peer}")
        
        last_command = ""
        try:
            while True:
                data = await reader.read(4096)
                if not data:
                    break
                
                payload, _ = self._parse_rpc_record(data)
                if not payload or len(payload) < 24:
                    continue
                
                xid, msg_type, rpc_vers, program, version, proc = struct.unpack(">IIIIII", payload[:24])
                
                # VXI-11 Command: device_write (Proc 11)
                if proc == 11 and len(payload) >= 40:
                    # Parse opaque string payload offset indices
                    opaque_len = struct.unpack(">I", payload[36:40])[0]
                    command = payload[40:40+opaque_len].decode('utf-8', errors='ignore').strip()
                    logger.info(f"[VXI11 WRITE] Received Query: '{command}'")
                    last_command = command
                    
                    # Formulate standard write response verification packet
                    reply_payload = struct.pack(">IIIIIIII", xid, 1, 0, 0, 0, 0, 0, opaque_len)
                    frag_header = struct.pack(">I", len(reply_payload) | 0x80000000)
                    writer.write(frag_header + reply_payload)
                    await writer.drain()
                
                # VXI-11 Command: device_read (Proc 12)
                elif proc == 12:
                    # Match identity keys required by your AutoIt structural checks
                    response_str = "TEKTRONIX,MSO58B,123456,CFG:V1.0\n" if last_command == "*IDN?" else "ERR: Unknown\n"
                    response_bytes = response_str.encode('utf-8')
                    opaque_padding = (4 - (len(response_bytes) % 4)) % 4
                    
                    logger.info(f"[VXI11 READ] Returning data payload descriptor: '{response_str.strip()}'")
                    
                    # Formulate response array block attributes matching the RPC specification
                    reply_payload = struct.pack(">IIIIIII", 
                        xid, 1, 0, 0, 0, 0, 
                        0, # Device error status code (0 = Success)
                    )
                    reply_payload += struct.pack(">II", 0x04, len(response_bytes)) # 0x04 = VXI-11 END bit marker
                    reply_payload += response_bytes + (b'\x00' * opaque_padding)
                    
                    frag_header = struct.pack(">I", len(reply_payload) | 0x80000000)
                    writer.write(frag_header + reply_payload)
                    await writer.drain()
        except Exception as e:
            logger.error(f"[VXI11 CORE] Connection processing exception tracking: {e}")
        finally:
            writer.close()

    async def start(self):
        # Fire up both structural protocol listeners in parallel
        try:
            self.pmap_server = await asyncio.start_server(self.handle_portmapper, self.host, 111)
            logger.info("Successfully bound mock RPC Portmapper service onto Port 111.")
        except PermissionError:
            logger.critical("CRITICAL: Port 111 requires administrator/root privileges to run.")
            return

        self.vxi_server = await asyncio.start_server(self.handle_vxi11_core, self.host, VXI11_CORE_PORT)
        logger.info(f"Successfully bound mock VXI-11 Core service onto Port {VXI11_CORE_PORT}.")
        logger.info("Server completely online. Awaiting NI-VISA framework polls...")
        
        await asyncio.gather(self.pmap_server.serve_forever(), self.vxi_server.serve_forever())

if __name__ == "__main__":
    server = PurePythonVxi11Mock()
    try:
        asyncio.run(server.start())
    except KeyboardInterrupt:
        logger.info("VXI-11 Simulation service safely closed down.")

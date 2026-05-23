import serial
import time
import sys

port = sys.argv[1]
binfile = sys.argv[2]

ser = serial.Serial(port, 19200, timeout=2)
time.sleep(0.5)

print("Waiting for bootloader...")
# drain any existing data
ser.reset_input_buffer()

# send space to abort autoboot
ser.write(b' ')
time.sleep(0.5)

# wait for CMD:> prompt
response = ser.read(100).decode(errors='ignore')
print(f"Got: {repr(response)}")

# send u for upload
print("Sending upload command...")
ser.write(b'u')
time.sleep(0.5)

response = ser.read(50).decode(errors='ignore')
print(f"Got: {repr(response)}")

# now send the binary file
print("Sending binary...")
with open(binfile, 'rb') as f:
    data = f.read()

ser.write(data)
print(f"Sent {len(data)} bytes")

# wait for OK
time.sleep(3)
response = ser.read(200).decode(errors='ignore')
print(f"Response: {repr(response)}")

if 'OK' in response:
    print("Upload successful! Executing...")
    ser.write(b'e')
else:
    print("Upload failed or timed out")
    print("Full response:", repr(response))

ser.close()

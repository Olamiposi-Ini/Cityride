CREATE TYPE "VehicleType" AS ENUM ('CAB', 'BUS', 'KEKE');

ALTER TABLE "DriverProfile"
ALTER COLUMN "vehicleType" TYPE "VehicleType"
USING (
  CASE upper("vehicleType")
    WHEN 'CAB' THEN 'CAB'
    WHEN 'CAR' THEN 'CAB'
    WHEN 'BUS' THEN 'BUS'
    WHEN 'KEKE' THEN 'KEKE'
    ELSE NULL
  END
)::"VehicleType";

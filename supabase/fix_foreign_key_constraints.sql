-- Fix foreign key constraints to allow cascading deletes
-- This prevents the foreign key constraint error when deleting from duo_farms

-- Drop the existing foreign key constraint
ALTER TABLE plant_inventory 
DROP CONSTRAINT IF EXISTS plant_inventory_room_id_fkey;

-- Add the constraint back with CASCADE delete behavior
ALTER TABLE plant_inventory 
ADD CONSTRAINT plant_inventory_room_id_fkey 
FOREIGN KEY (room_id) 
REFERENCES duo_farms(room_id) 
ON DELETE CASCADE;

-- Also fix animal_health table if it exists
ALTER TABLE animal_health 
DROP CONSTRAINT IF EXISTS animal_health_room_id_fkey;

ALTER TABLE animal_health 
ADD CONSTRAINT animal_health_room_id_fkey 
FOREIGN KEY (room_id) 
REFERENCES duo_farms(room_id) 
ON DELETE CASCADE;

-- And farm_ecosystem table if it exists
ALTER TABLE farm_ecosystem 
DROP CONSTRAINT IF EXISTS farm_ecosystem_room_id_fkey;

ALTER TABLE farm_ecosystem 
ADD CONSTRAINT farm_ecosystem_room_id_fkey 
FOREIGN KEY (room_id) 
REFERENCES duo_farms(room_id) 
ON DELETE CASCADE;
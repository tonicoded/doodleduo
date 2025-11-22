-- Enable Row Level Security for new ecosystem tables
-- This ensures users can only access their own farm data

-- Enable RLS on all ecosystem tables
ALTER TABLE animal_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE plant_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE farm_ecosystem ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for animal_health table
CREATE POLICY "Users can view their own animal health" ON animal_health
    FOR SELECT USING (
        room_id IN (
            SELECT dm.room_id 
            FROM duo_memberships dm 
            WHERE dm.profile_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert animal health for their rooms" ON animal_health
    FOR INSERT WITH CHECK (
        room_id IN (
            SELECT dm.room_id 
            FROM duo_memberships dm 
            WHERE dm.profile_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their own animal health" ON animal_health
    FOR UPDATE USING (
        room_id IN (
            SELECT dm.room_id 
            FROM duo_memberships dm 
            WHERE dm.profile_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete their own animal health" ON animal_health
    FOR DELETE USING (
        room_id IN (
            SELECT dm.room_id 
            FROM duo_memberships dm 
            WHERE dm.profile_id = auth.uid()
        )
    );

-- Create RLS policies for plant_inventory table
CREATE POLICY "Users can view their own plant inventory" ON plant_inventory
    FOR SELECT USING (
        room_id IN (
            SELECT dm.room_id 
            FROM duo_memberships dm 
            WHERE dm.profile_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert plants for their rooms" ON plant_inventory
    FOR INSERT WITH CHECK (
        room_id IN (
            SELECT dm.room_id 
            FROM duo_memberships dm 
            WHERE dm.profile_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their own plant inventory" ON plant_inventory
    FOR UPDATE USING (
        room_id IN (
            SELECT dm.room_id 
            FROM duo_memberships dm 
            WHERE dm.profile_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete their own plant inventory" ON plant_inventory
    FOR DELETE USING (
        room_id IN (
            SELECT dm.room_id 
            FROM duo_memberships dm 
            WHERE dm.profile_id = auth.uid()
        )
    );

-- Create RLS policies for farm_ecosystem table
CREATE POLICY "Users can view their own ecosystem" ON farm_ecosystem
    FOR SELECT USING (
        room_id IN (
            SELECT dm.room_id 
            FROM duo_memberships dm 
            WHERE dm.profile_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert ecosystem for their rooms" ON farm_ecosystem
    FOR INSERT WITH CHECK (
        room_id IN (
            SELECT dm.room_id 
            FROM duo_memberships dm 
            WHERE dm.profile_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their own ecosystem" ON farm_ecosystem
    FOR UPDATE USING (
        room_id IN (
            SELECT dm.room_id 
            FROM duo_memberships dm 
            WHERE dm.profile_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete their own ecosystem" ON farm_ecosystem
    FOR DELETE USING (
        room_id IN (
            SELECT dm.room_id 
            FROM duo_memberships dm 
            WHERE dm.profile_id = auth.uid()
        )
    );

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON animal_health TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON plant_inventory TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON farm_ecosystem TO authenticated;
-- Clean up duplicate animal health records
-- Keep only the newest record for each animal type per room

-- First, let's see what duplicates we have
SELECT
    room_id,
    animal_type,
    COUNT(*) as count,
    array_agg(animal_id ORDER BY created_at DESC) as animal_ids,
    array_agg(hours_until_death ORDER BY created_at DESC) as health_values
FROM animal_health
GROUP BY room_id, animal_type
HAVING COUNT(*) > 1;

-- Delete old duplicate records, keeping only the one with the highest health
DELETE FROM animal_health
WHERE animal_id IN (
    SELECT ah.animal_id
    FROM animal_health ah
    INNER JOIN (
        SELECT
            room_id,
            animal_type,
            MAX(hours_until_death) as max_health
        FROM animal_health
        GROUP BY room_id, animal_type
    ) latest
    ON ah.room_id = latest.room_id
    AND ah.animal_type = latest.animal_type
    WHERE ah.hours_until_death < latest.max_health
);

-- Verify cleanup
SELECT
    room_id,
    animal_type,
    COUNT(*) as count
FROM animal_health
GROUP BY room_id, animal_type
ORDER BY room_id, animal_type;

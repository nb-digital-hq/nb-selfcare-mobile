// Generado por scripts/generar-sincronizacion.mjs de NB SelfCare. No se edita a mano.
// ignore_for_file: lines_longer_than_80_chars

/// Esquema 9 compartido con el escritorio (ADR-025).
const String esquemaSincronizacionV9 = r'''
-- Generado por scripts/generar-sincronizacion.mjs. No se edita a mano.
-- Esquema 9 de NB SelfCare, idéntico en escritorio y SelfCare Mobile (ADR-014).
-- No modifica tablas del esquema 8: añade identidades estables, revisiones, diario de
-- cambios, recibos y conflictos. Los disparadores capturan cada escritura en su misma
-- transacción; al aplicar un cambio remoto el propietario marca sc_sync_control.

CREATE TABLE sc_sync_contexto (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    epoca TEXT NOT NULL CHECK (length(epoca) = 32 AND epoca NOT GLOB '*[^0-9a-f]*')
);
INSERT INTO sc_sync_contexto (id, epoca) VALUES (1, lower(hex(randomblob(16))));
CREATE TABLE sc_sync_control (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    aplicando INTEGER NOT NULL DEFAULT 0 CHECK (aplicando IN (0, 1)),
    origen TEXT NULL CHECK (origen IS NULL OR (length(origen) = 32 AND origen NOT GLOB '*[^0-9a-f]*')),
    registro TEXT NULL CHECK (registro IS NULL OR (length(registro) = 32 AND registro NOT GLOB '*[^0-9a-f]*'))
);
INSERT INTO sc_sync_control (id, aplicando, origen, registro) VALUES (1, 0, NULL, NULL);
CREATE TABLE sc_sync_revisiones (
    entidad TEXT NOT NULL CHECK (length(entidad) BETWEEN 1 AND 32),
    registro TEXT NOT NULL CHECK (length(registro) = 32 AND registro NOT GLOB '*[^0-9a-f]*'),
    revision INTEGER NOT NULL CHECK (typeof(revision) = 'integer' AND revision BETWEEN 1 AND 9007199254740991),
    PRIMARY KEY (entidad, registro)
);
CREATE TABLE sc_sync_identidades (
    tabla TEXT NOT NULL,
    clave TEXT NOT NULL,
    registro TEXT NOT NULL UNIQUE CHECK (length(registro) = 32 AND registro NOT GLOB '*[^0-9a-f]*'),
    compartida INTEGER NOT NULL DEFAULT 0 CHECK (compartida BETWEEN 0 AND 9007199254740991),
    eliminado INTEGER NOT NULL DEFAULT 0 CHECK (eliminado IN (0, 1)),
    en_conflicto INTEGER NOT NULL DEFAULT 0 CHECK (en_conflicto IN (0, 1)),
    PRIMARY KEY (tabla, clave)
);
CREATE TABLE sc_sync_diario (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    registro TEXT NOT NULL UNIQUE REFERENCES sc_sync_identidades (registro) ON UPDATE CASCADE,
    origen TEXT NULL
);
CREATE TABLE sc_sync_recibos (
    nodo TEXT NOT NULL CHECK (length(nodo) = 32 AND nodo NOT GLOB '*[^0-9a-f]*'),
    operacion TEXT NOT NULL CHECK (length(operacion) = 32 AND operacion NOT GLOB '*[^0-9a-f]*'),
    epoca TEXT NOT NULL CHECK (length(epoca) = 32 AND epoca NOT GLOB '*[^0-9a-f]*'),
    huella BLOB NOT NULL CHECK (typeof(huella) = 'blob' AND length(huella) = 32),
    resultado TEXT NOT NULL CHECK (resultado IN ('aplicado', 'conflicto')),
    revision INTEGER NOT NULL CHECK (typeof(revision) = 'integer' AND revision BETWEEN 0 AND 9007199254740991),
    PRIMARY KEY (nodo, operacion)
);
CREATE TABLE sc_sync_conflictos (
    nodo TEXT NOT NULL,
    operacion TEXT NOT NULL,
    actual TEXT CHECK (actual IS NULL OR (json_valid(actual) AND json_type(actual) = 'object'
        AND length(CAST(actual AS BLOB)) <= 65536)),
    propuesta TEXT NOT NULL CHECK (json_valid(propuesta) AND json_type(propuesta) = 'object'
        AND length(CAST(propuesta AS BLOB)) <= 69632),
    PRIMARY KEY (nodo, operacion),
    FOREIGN KEY (nodo, operacion) REFERENCES sc_sync_recibos(nodo, operacion) ON DELETE RESTRICT
);
CREATE TABLE sc_sync_pares (
    nodo TEXT NOT NULL PRIMARY KEY CHECK (length(nodo) = 32 AND nodo NOT GLOB '*[^0-9a-f]*'),
    epoca TEXT NULL,
    cursor INTEGER NOT NULL DEFAULT 0 CHECK (cursor >= 0),
    ultima TEXT NULL
);

-- user_profiles (perfil)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'user_profiles', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "user_profiles";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'perfil', registro, 1 FROM sc_sync_identidades WHERE tabla = 'user_profiles';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "user_profiles" f JOIN sc_sync_identidades i
    ON i.tabla = 'user_profiles' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_user_profiles_ai AFTER INSERT ON "user_profiles" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('user_profiles', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'user_profiles' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'perfil', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'user_profiles' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'user_profiles' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'user_profiles' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_user_profiles_au AFTER UPDATE OF "name", "birth_date", "biological_sex", "height_cm", "target_weight_kg", "weekly_goal_rate_kg", "daily_water_goal_ml", "daily_steps_goal", "daily_sleep_goal_hours", "is_cycle_tracking_enabled", "is_fasting_enabled", "is_manual_macro_mode", "manual_kcal_target", "manual_protein_g", "manual_carbs_g", "manual_fat_g", "active_diet_archetype", "active_diet_phase", "calorie_cycling_schedule_json", "caffeine_bedtime_cutoff_hours", "active_diet_phase_started_at", "has_impedance_contraindication", "has_eating_disorder_history", "takes_hypoglycemic_medication", "target_bedtime_minutes", "created_at" ON "user_profiles" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'user_profiles' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'perfil', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'user_profiles' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'user_profiles' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'user_profiles' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_user_profiles_ad AFTER DELETE ON "user_profiles" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'user_profiles' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'user_profiles' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'perfil', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'user_profiles' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'user_profiles' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'user_profiles' AND clave = CAST(OLD."id" AS TEXT);
END;

-- pet_status (inventario_nibi)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'pet_status', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "pet_status";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'inventario_nibi', registro, 1 FROM sc_sync_identidades WHERE tabla = 'pet_status';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "pet_status" f JOIN sc_sync_identidades i
    ON i.tabla = 'pet_status' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_pet_status_ai AFTER INSERT ON "pet_status" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('pet_status', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'pet_status' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'inventario_nibi', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'pet_status' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'pet_status' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'pet_status' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_pet_status_au AFTER UPDATE OF "pet_name", "equipped_hat_id", "equipped_accessory_id", "equipped_color_id", "equipped_background_id", "unlocked_items_json" ON "pet_status" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'pet_status' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'inventario_nibi', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'pet_status' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'pet_status' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'pet_status' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_pet_status_ad AFTER DELETE ON "pet_status" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'pet_status' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'pet_status' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'inventario_nibi', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'pet_status' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'pet_status' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'pet_status' AND clave = CAST(OLD."id" AS TEXT);
END;

-- daily_summaries (descanso)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'daily_summaries', CAST("date_key" AS TEXT), lower(hex(randomblob(16))) FROM "daily_summaries";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'descanso', registro, 1 FROM sc_sync_identidades WHERE tabla = 'daily_summaries';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "daily_summaries" f JOIN sc_sync_identidades i
    ON i.tabla = 'daily_summaries' AND i.clave = CAST(f."date_key" AS TEXT);
CREATE TRIGGER sc_sync_daily_summaries_ai AFTER INSERT ON "daily_summaries" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('daily_summaries', CAST(NEW."date_key" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'daily_summaries' AND clave = CAST(NEW."date_key" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'descanso', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'daily_summaries' AND clave = CAST(NEW."date_key" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'daily_summaries' AND clave = CAST(NEW."date_key" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'daily_summaries' AND clave = CAST(NEW."date_key" AS TEXT);
END;
CREATE TRIGGER sc_sync_daily_summaries_au AFTER UPDATE OF "date_key", "steps_count", "active_calories_from_steps", "sleep_duration_minutes", "sleep_deep_minutes", "sleep_rem_minutes", "resting_heart_rate_bpm", "wake_time_minutes", "calorie_target_kcal", "protein_target_g", "carbs_target_g", "fat_target_g" ON "daily_summaries" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'daily_summaries' AND clave = CAST(NEW."date_key" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'descanso', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'daily_summaries' AND clave = CAST(NEW."date_key" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'daily_summaries' AND clave = CAST(NEW."date_key" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'daily_summaries' AND clave = CAST(NEW."date_key" AS TEXT);
END;
CREATE TRIGGER sc_sync_daily_summaries_ad AFTER DELETE ON "daily_summaries" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'daily_summaries' AND clave = CAST(OLD."date_key" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'daily_summaries' AND clave = CAST(OLD."date_key" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'descanso', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'daily_summaries' AND clave = CAST(OLD."date_key" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'daily_summaries' AND clave = CAST(OLD."date_key" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'daily_summaries' AND clave = CAST(OLD."date_key" AS TEXT);
END;

-- food_items (alimento)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'food_items', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "food_items";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'alimento', registro, 1 FROM sc_sync_identidades WHERE tabla = 'food_items';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "food_items" f JOIN sc_sync_identidades i
    ON i.tabla = 'food_items' AND i.clave = CAST(f."id" AS TEXT) WHERE f.source <> 'usda_seed';
CREATE TRIGGER sc_sync_food_items_ai AFTER INSERT ON "food_items" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('food_items', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'food_items' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'alimento', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'food_items' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0 AND NEW.source <> 'usda_seed'
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'food_items' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'food_items' AND clave = CAST(NEW."id" AS TEXT) AND NEW.source <> 'usda_seed';
END;
CREATE TRIGGER sc_sync_food_items_au AFTER UPDATE OF "barcode", "name", "brand", "source", "nutri_score", "nova_group", "default_serving_grams", "serving_label", "kcal_per100g", "protein_per100g", "carbs_per100g", "fat_per100g", "fiber_per100g", "sugar_per100g", "sodium_mg_per100g", "potassium_mg_per100g", "magnesium_mg_per100g", "calcium_mg_per100g", "iron_mg_per100g", "zinc_mg_per100g", "vitamin_c_mg_per100g", "vitamin_d_ug_per100g", "vitamin_b12_ug_per100g", "is_favorite", "last_used_at" ON "food_items" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'food_items' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'alimento', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'food_items' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0 AND NEW.source <> 'usda_seed'
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'food_items' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'food_items' AND clave = CAST(NEW."id" AS TEXT) AND NEW.source <> 'usda_seed';
END;
CREATE TRIGGER sc_sync_food_items_ad AFTER DELETE ON "food_items" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'food_items' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'food_items' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'alimento', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'food_items' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0 AND OLD.source <> 'usda_seed'
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'food_items' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'food_items' AND clave = CAST(OLD."id" AS TEXT) AND OLD.source <> 'usda_seed';
END;

-- meal_combos (combo)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'meal_combos', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "meal_combos";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'combo', registro, 1 FROM sc_sync_identidades WHERE tabla = 'meal_combos';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "meal_combos" f JOIN sc_sync_identidades i
    ON i.tabla = 'meal_combos' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_meal_combos_ai AFTER INSERT ON "meal_combos" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('meal_combos', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'meal_combos' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'combo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'meal_combos' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'meal_combos' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'meal_combos' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_meal_combos_au AFTER UPDATE OF "name", "default_meal_type", "times_used" ON "meal_combos" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'meal_combos' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'combo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'meal_combos' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'meal_combos' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'meal_combos' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_meal_combos_ad AFTER DELETE ON "meal_combos" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'meal_combos' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'meal_combos' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'combo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'meal_combos' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'meal_combos' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'meal_combos' AND clave = CAST(OLD."id" AS TEXT);
END;

-- meal_combo_items (combo_alimento)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'meal_combo_items', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "meal_combo_items";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'combo_alimento', registro, 1 FROM sc_sync_identidades WHERE tabla = 'meal_combo_items';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "meal_combo_items" f JOIN sc_sync_identidades i
    ON i.tabla = 'meal_combo_items' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_meal_combo_items_ai AFTER INSERT ON "meal_combo_items" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('meal_combo_items', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'meal_combo_items' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'combo_alimento', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'meal_combo_items' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'meal_combo_items' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'meal_combo_items' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_meal_combo_items_au AFTER UPDATE OF "combo_id", "food_item_id", "base_grams" ON "meal_combo_items" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'meal_combo_items' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'combo_alimento', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'meal_combo_items' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'meal_combo_items' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'meal_combo_items' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_meal_combo_items_ad AFTER DELETE ON "meal_combo_items" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'meal_combo_items' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'meal_combo_items' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'combo_alimento', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'meal_combo_items' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'meal_combo_items' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'meal_combo_items' AND clave = CAST(OLD."id" AS TEXT);
END;

-- recipes (receta)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'recipes', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "recipes";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'receta', registro, 1 FROM sc_sync_identidades WHERE tabla = 'recipes';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "recipes" f JOIN sc_sync_identidades i
    ON i.tabla = 'recipes' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_recipes_ai AFTER INSERT ON "recipes" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('recipes', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'recipes' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'receta', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'recipes' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'recipes' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'recipes' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_recipes_au AFTER UPDATE OF "name", "description", "default_meal_type", "total_yield_servings", "cooked_total_weight_grams", "kcal_per_serving", "protein_per_serving", "carbs_per_serving", "fat_per_serving", "fiber_per_serving", "sodium_mg_per_serving", "potassium_mg_per_serving", "magnesium_mg_per_serving", "created_at", "last_used_at" ON "recipes" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'recipes' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'receta', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'recipes' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'recipes' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'recipes' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_recipes_ad AFTER DELETE ON "recipes" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'recipes' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'recipes' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'receta', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'recipes' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'recipes' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'recipes' AND clave = CAST(OLD."id" AS TEXT);
END;

-- recipe_ingredients (ingrediente)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'recipe_ingredients', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "recipe_ingredients";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'ingrediente', registro, 1 FROM sc_sync_identidades WHERE tabla = 'recipe_ingredients';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "recipe_ingredients" f JOIN sc_sync_identidades i
    ON i.tabla = 'recipe_ingredients' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_recipe_ingredients_ai AFTER INSERT ON "recipe_ingredients" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('recipe_ingredients', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'recipe_ingredients' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'ingrediente', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'recipe_ingredients' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'recipe_ingredients' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'recipe_ingredients' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_recipe_ingredients_au AFTER UPDATE OF "recipe_id", "food_item_id", "raw_grams" ON "recipe_ingredients" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'recipe_ingredients' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'ingrediente', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'recipe_ingredients' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'recipe_ingredients' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'recipe_ingredients' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_recipe_ingredients_ad AFTER DELETE ON "recipe_ingredients" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'recipe_ingredients' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'recipe_ingredients' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'ingrediente', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'recipe_ingredients' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'recipe_ingredients' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'recipe_ingredients' AND clave = CAST(OLD."id" AS TEXT);
END;

-- food_logs (comida)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'food_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "food_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'comida', registro, 1 FROM sc_sync_identidades WHERE tabla = 'food_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "food_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'food_logs' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_food_logs_ai AFTER INSERT ON "food_logs" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('food_logs', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'food_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'comida', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'food_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'food_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'food_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_food_logs_au AFTER UPDATE OF "date_key", "logged_at", "meal_type", "food_item_id", "grams_consumed", "portion_multiplier", "total_kcal", "total_protein_g", "total_carbs_g", "total_fat_g", "total_fiber_g", "total_sodium_mg", "total_potassium_mg", "total_magnesium_mg" ON "food_logs" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'food_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'comida', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'food_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'food_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'food_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_food_logs_ad AFTER DELETE ON "food_logs" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'food_logs' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'food_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'comida', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'food_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'food_logs' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'food_logs' AND clave = CAST(OLD."id" AS TEXT);
END;

-- hydration_logs (agua)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'hydration_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "hydration_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'agua', registro, 1 FROM sc_sync_identidades WHERE tabla = 'hydration_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "hydration_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'hydration_logs' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_hydration_logs_ai AFTER INSERT ON "hydration_logs" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('hydration_logs', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'hydration_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'agua', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'hydration_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'hydration_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'hydration_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_hydration_logs_au AFTER UPDATE OF "date_key", "logged_at", "volume_ml" ON "hydration_logs" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'hydration_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'agua', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'hydration_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'hydration_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'hydration_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_hydration_logs_ad AFTER DELETE ON "hydration_logs" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'hydration_logs' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'hydration_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'agua', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'hydration_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'hydration_logs' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'hydration_logs' AND clave = CAST(OLD."id" AS TEXT);
END;

-- body_measurements (peso)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'body_measurements', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "body_measurements";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'peso', registro, 1 FROM sc_sync_identidades WHERE tabla = 'body_measurements';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "body_measurements" f JOIN sc_sync_identidades i
    ON i.tabla = 'body_measurements' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_body_measurements_ai AFTER INSERT ON "body_measurements" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('body_measurements', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'body_measurements' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'peso', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'body_measurements' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'body_measurements' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'body_measurements' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_body_measurements_au AFTER UPDATE OF "measured_at", "date_key", "source", "weight_kg", "trend_weight_kg", "impedance_ohms", "bmi", "body_fat_percentage", "muscle_mass_kg", "water_percentage", "visceral_fat_index", "bone_mass_kg", "protein_percentage", "basal_metabolic_rate_kcal", "metabolic_age", "lean_body_mass_kg", "body_score", "somatotype", "waist_cm", "neck_cm", "hip_cm", "validated_body_fat_percentage", "is_water_retention_spike", "spike_explanation" ON "body_measurements" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'body_measurements' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'peso', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'body_measurements' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'body_measurements' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'body_measurements' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_body_measurements_ad AFTER DELETE ON "body_measurements" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'body_measurements' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'body_measurements' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'peso', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'body_measurements' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'body_measurements' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'body_measurements' AND clave = CAST(OLD."id" AS TEXT);
END;

-- workout_blocks (entrenamiento)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'workout_blocks', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "workout_blocks";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'entrenamiento', registro, 1 FROM sc_sync_identidades WHERE tabla = 'workout_blocks';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "workout_blocks" f JOIN sc_sync_identidades i
    ON i.tabla = 'workout_blocks' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_workout_blocks_ai AFTER INSERT ON "workout_blocks" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('workout_blocks', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'workout_blocks' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'entrenamiento', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'workout_blocks' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'workout_blocks' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'workout_blocks' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_workout_blocks_au AFTER UPDATE OF "date_key", "performed_at", "category", "duration_minutes", "rpe_intensity", "applied_met", "user_weight_at_time_kg", "net_calories_burned" ON "workout_blocks" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'workout_blocks' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'entrenamiento', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'workout_blocks' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'workout_blocks' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'workout_blocks' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_workout_blocks_ad AFTER DELETE ON "workout_blocks" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'workout_blocks' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'workout_blocks' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'entrenamiento', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'workout_blocks' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'workout_blocks' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'workout_blocks' AND clave = CAST(OLD."id" AS TEXT);
END;

-- fasting_sessions (ayuno)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'fasting_sessions', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "fasting_sessions";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'ayuno', registro, 1 FROM sc_sync_identidades WHERE tabla = 'fasting_sessions';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "fasting_sessions" f JOIN sc_sync_identidades i
    ON i.tabla = 'fasting_sessions' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_fasting_sessions_ai AFTER INSERT ON "fasting_sessions" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('fasting_sessions', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'fasting_sessions' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'ayuno', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'fasting_sessions' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'fasting_sessions' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'fasting_sessions' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_fasting_sessions_au AFTER UPDATE OF "protocol_name", "target_hours", "started_at", "planned_end_at", "actual_ended_at", "is_completed", "notes" ON "fasting_sessions" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'fasting_sessions' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'ayuno', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'fasting_sessions' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'fasting_sessions' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'fasting_sessions' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_fasting_sessions_ad AFTER DELETE ON "fasting_sessions" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'fasting_sessions' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'fasting_sessions' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'ayuno', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'fasting_sessions' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'fasting_sessions' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'fasting_sessions' AND clave = CAST(OLD."id" AS TEXT);
END;

-- journal_entries (diario)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'journal_entries', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "journal_entries";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'diario', registro, 1 FROM sc_sync_identidades WHERE tabla = 'journal_entries';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "journal_entries" f JOIN sc_sync_identidades i
    ON i.tabla = 'journal_entries' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_journal_entries_ai AFTER INSERT ON "journal_entries" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('journal_entries', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'journal_entries' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'diario', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'journal_entries' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'journal_entries' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'journal_entries' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_journal_entries_au AFTER UPDATE OF "date_key", "created_at", "content", "mood_score", "energy_level", "stress_level", "tags_json" ON "journal_entries" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'journal_entries' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'diario', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'journal_entries' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'journal_entries' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'journal_entries' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_journal_entries_ad AFTER DELETE ON "journal_entries" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'journal_entries' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'journal_entries' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'diario', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'journal_entries' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'journal_entries' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'journal_entries' AND clave = CAST(OLD."id" AS TEXT);
END;

-- coin_ledger (accion_nibi)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'coin_ledger', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "coin_ledger";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'accion_nibi', registro, 1 FROM sc_sync_identidades WHERE tabla = 'coin_ledger';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "coin_ledger" f JOIN sc_sync_identidades i
    ON i.tabla = 'coin_ledger' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_coin_ledger_ai AFTER INSERT ON "coin_ledger" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('coin_ledger', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'coin_ledger' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'accion_nibi', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'coin_ledger' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'coin_ledger' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'coin_ledger' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_coin_ledger_au AFTER UPDATE OF "created_at", "date_key", "action_type", "amount", "sleep_multiplier_applied" ON "coin_ledger" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'coin_ledger' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'accion_nibi', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'coin_ledger' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'coin_ledger' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'coin_ledger' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_coin_ledger_ad AFTER DELETE ON "coin_ledger" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'coin_ledger' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'coin_ledger' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'accion_nibi', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'coin_ledger' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'coin_ledger' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'coin_ledger' AND clave = CAST(OLD."id" AS TEXT);
END;

-- supplements_tracker (tratamiento)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'supplements_tracker', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "supplements_tracker";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'tratamiento', registro, 1 FROM sc_sync_identidades WHERE tabla = 'supplements_tracker';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "supplements_tracker" f JOIN sc_sync_identidades i
    ON i.tabla = 'supplements_tracker' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_supplements_tracker_ai AFTER INSERT ON "supplements_tracker" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('supplements_tracker', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'supplements_tracker' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'tratamiento', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'supplements_tracker' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'supplements_tracker' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'supplements_tracker' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_supplements_tracker_au AFTER UPDATE OF "name", "dosage", "target_time_of_day_minutes", "affects_water_retention", "is_enabled", "created_at", "kind", "schedule_json", "days_of_week_bitmask", "stock_units", "units_per_dose", "reminders_enabled", "lowers_glucose", "notes" ON "supplements_tracker" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'supplements_tracker' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'tratamiento', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'supplements_tracker' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'supplements_tracker' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'supplements_tracker' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_supplements_tracker_ad AFTER DELETE ON "supplements_tracker" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'supplements_tracker' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'supplements_tracker' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'tratamiento', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'supplements_tracker' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'supplements_tracker' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'supplements_tracker' AND clave = CAST(OLD."id" AS TEXT);
END;

-- supplement_logs (toma)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'supplement_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "supplement_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'toma', registro, 1 FROM sc_sync_identidades WHERE tabla = 'supplement_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "supplement_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'supplement_logs' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_supplement_logs_ai AFTER INSERT ON "supplement_logs" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('supplement_logs', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'supplement_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'toma', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'supplement_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'supplement_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'supplement_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_supplement_logs_au AFTER UPDATE OF "date_key", "supplement_id", "taken_at", "was_taken", "slot_minutes" ON "supplement_logs" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'supplement_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'toma', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'supplement_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'supplement_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'supplement_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_supplement_logs_ad AFTER DELETE ON "supplement_logs" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'supplement_logs' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'supplement_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'toma', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'supplement_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'supplement_logs' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'supplement_logs' AND clave = CAST(OLD."id" AS TEXT);
END;

-- female_cycle_logs (ciclo)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'female_cycle_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "female_cycle_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'ciclo', registro, 1 FROM sc_sync_identidades WHERE tabla = 'female_cycle_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "female_cycle_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'female_cycle_logs' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_female_cycle_logs_ai AFTER INSERT ON "female_cycle_logs" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('female_cycle_logs', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'female_cycle_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'ciclo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'female_cycle_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'female_cycle_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'female_cycle_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_female_cycle_logs_au AFTER UPDATE OF "cycle_start_date", "cycle_end_date", "cycle_length_days", "flow_intensity", "symptoms_json", "notes" ON "female_cycle_logs" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'female_cycle_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'ciclo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'female_cycle_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'female_cycle_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'female_cycle_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_female_cycle_logs_ad AFTER DELETE ON "female_cycle_logs" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'female_cycle_logs' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'female_cycle_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'ciclo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'female_cycle_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'female_cycle_logs' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'female_cycle_logs' AND clave = CAST(OLD."id" AS TEXT);
END;

-- digestive_logs (digestion)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'digestive_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "digestive_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'digestion', registro, 1 FROM sc_sync_identidades WHERE tabla = 'digestive_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "digestive_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'digestive_logs' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_digestive_logs_ai AFTER INSERT ON "digestive_logs" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('digestive_logs', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'digestive_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'digestion', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'digestive_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'digestive_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'digestive_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_digestive_logs_au AFTER UPDATE OF "date_key", "logged_at", "bristol_type", "discomfort_level", "symptoms_json", "notes" ON "digestive_logs" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'digestive_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'digestion', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'digestive_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'digestive_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'digestive_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_digestive_logs_ad AFTER DELETE ON "digestive_logs" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'digestive_logs' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'digestive_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'digestion', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'digestive_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'digestive_logs' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'digestive_logs' AND clave = CAST(OLD."id" AS TEXT);
END;

-- caffeine_logs (cafeina)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'caffeine_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "caffeine_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'cafeina', registro, 1 FROM sc_sync_identidades WHERE tabla = 'caffeine_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "caffeine_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'caffeine_logs' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_caffeine_logs_ai AFTER INSERT ON "caffeine_logs" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('caffeine_logs', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'caffeine_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'cafeina', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'caffeine_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'caffeine_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'caffeine_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_caffeine_logs_au AFTER UPDATE OF "date_key", "logged_at", "source_name", "caffeine_mg" ON "caffeine_logs" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'caffeine_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'cafeina', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'caffeine_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'caffeine_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'caffeine_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_caffeine_logs_ad AFTER DELETE ON "caffeine_logs" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'caffeine_logs' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'caffeine_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'cafeina', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'caffeine_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'caffeine_logs' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'caffeine_logs' AND clave = CAST(OLD."id" AS TEXT);
END;

-- protocol_plans (plan)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'protocol_plans', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "protocol_plans";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'plan', registro, 1 FROM sc_sync_identidades WHERE tabla = 'protocol_plans';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "protocol_plans" f JOIN sc_sync_identidades i
    ON i.tabla = 'protocol_plans' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_protocol_plans_ai AFTER INSERT ON "protocol_plans" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('protocol_plans', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'protocol_plans' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'plan', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'protocol_plans' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'protocol_plans' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'protocol_plans' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_protocol_plans_au AFTER UPDATE OF "plan_name", "fasting_days_bitmask", "workout_slots_json", "diet_archetype", "is_current_active", "updated_at" ON "protocol_plans" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'protocol_plans' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'plan', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'protocol_plans' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'protocol_plans' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'protocol_plans' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_protocol_plans_ad AFTER DELETE ON "protocol_plans" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'protocol_plans' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'protocol_plans' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'plan', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'protocol_plans' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'protocol_plans' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'protocol_plans' AND clave = CAST(OLD."id" AS TEXT);
END;

-- milestone_goals (meta)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'milestone_goals', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "milestone_goals";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'meta', registro, 1 FROM sc_sync_identidades WHERE tabla = 'milestone_goals';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "milestone_goals" f JOIN sc_sync_identidades i
    ON i.tabla = 'milestone_goals' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_milestone_goals_ai AFTER INSERT ON "milestone_goals" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('milestone_goals', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'milestone_goals' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'meta', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'milestone_goals' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'milestone_goals' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'milestone_goals' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_milestone_goals_au AFTER UPDATE OF "milestone_order", "target_weight_kg", "is_completed", "completed_at", "estimated_completion_date" ON "milestone_goals" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'milestone_goals' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'meta', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'milestone_goals' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'milestone_goals' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'milestone_goals' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_milestone_goals_ad AFTER DELETE ON "milestone_goals" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'milestone_goals' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'milestone_goals' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'meta', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'milestone_goals' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'milestone_goals' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'milestone_goals' AND clave = CAST(OLD."id" AS TEXT);
END;

-- care_sessions (sesion_cuidado)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'care_sessions', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "care_sessions";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'sesion_cuidado', registro, 1 FROM sc_sync_identidades WHERE tabla = 'care_sessions';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "care_sessions" f JOIN sc_sync_identidades i
    ON i.tabla = 'care_sessions' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_care_sessions_ai AFTER INSERT ON "care_sessions" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('care_sessions', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'care_sessions' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'sesion_cuidado', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'care_sessions' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'care_sessions' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'care_sessions' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_care_sessions_au AFTER UPDATE OF "date_key", "completed_at", "kind", "variant", "duration_seconds" ON "care_sessions" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'care_sessions' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'sesion_cuidado', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'care_sessions' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'care_sessions' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'care_sessions' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_care_sessions_ad AFTER DELETE ON "care_sessions" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'care_sessions' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'care_sessions' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'sesion_cuidado', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'care_sessions' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'care_sessions' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'care_sessions' AND clave = CAST(OLD."id" AS TEXT);
END;

-- custom_habits (habito)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'custom_habits', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "custom_habits";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'habito', registro, 1 FROM sc_sync_identidades WHERE tabla = 'custom_habits';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "custom_habits" f JOIN sc_sync_identidades i
    ON i.tabla = 'custom_habits' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_custom_habits_ai AFTER INSERT ON "custom_habits" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('custom_habits', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'custom_habits' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'habito', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'custom_habits' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'custom_habits' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'custom_habits' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_custom_habits_au AFTER UPDATE OF "name", "icon_key", "days_of_week_bitmask", "sort_order", "is_archived", "created_at" ON "custom_habits" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'custom_habits' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'habito', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'custom_habits' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'custom_habits' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'custom_habits' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_custom_habits_ad AFTER DELETE ON "custom_habits" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'custom_habits' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'custom_habits' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'habito', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'custom_habits' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'custom_habits' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'custom_habits' AND clave = CAST(OLD."id" AS TEXT);
END;

-- habit_logs (habito_hecho)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'habit_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "habit_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'habito_hecho', registro, 1 FROM sc_sync_identidades WHERE tabla = 'habit_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "habit_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'habit_logs' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_habit_logs_ai AFTER INSERT ON "habit_logs" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('habit_logs', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'habit_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'habito_hecho', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'habit_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'habit_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'habit_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_habit_logs_au AFTER UPDATE OF "habit_id", "date_key", "logged_at" ON "habit_logs" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'habit_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'habito_hecho', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'habit_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'habit_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'habit_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_habit_logs_ad AFTER DELETE ON "habit_logs" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'habit_logs' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'habit_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'habito_hecho', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'habit_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'habit_logs' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'habit_logs' AND clave = CAST(OLD."id" AS TEXT);
END;

-- checkups (chequeo)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'checkups', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "checkups";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'chequeo', registro, 1 FROM sc_sync_identidades WHERE tabla = 'checkups';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "checkups" f JOIN sc_sync_identidades i
    ON i.tabla = 'checkups' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_checkups_ai AFTER INSERT ON "checkups" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('checkups', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'checkups' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'chequeo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'checkups' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'checkups' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'checkups' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_checkups_au AFTER UPDATE OF "catalog_key", "custom_name", "interval_months", "is_enabled" ON "checkups" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'checkups' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'chequeo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'checkups' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'checkups' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'checkups' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_checkups_ad AFTER DELETE ON "checkups" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'checkups' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'checkups' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'chequeo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'checkups' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'checkups' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'checkups' AND clave = CAST(OLD."id" AS TEXT);
END;

-- checkup_logs (chequeo_hecho)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'checkup_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "checkup_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'chequeo_hecho', registro, 1 FROM sc_sync_identidades WHERE tabla = 'checkup_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "checkup_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'checkup_logs' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_checkup_logs_ai AFTER INSERT ON "checkup_logs" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('checkup_logs', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'checkup_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'chequeo_hecho', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'checkup_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'checkup_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'checkup_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_checkup_logs_au AFTER UPDATE OF "checkup_id", "done_at", "notes" ON "checkup_logs" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'checkup_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'chequeo_hecho', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'checkup_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'checkup_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'checkup_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_checkup_logs_ad AFTER DELETE ON "checkup_logs" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'checkup_logs' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'checkup_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'chequeo_hecho', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'checkup_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'checkup_logs' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'checkup_logs' AND clave = CAST(OLD."id" AS TEXT);
END;

-- symptom_logs (sintoma)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'symptom_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "symptom_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'sintoma', registro, 1 FROM sc_sync_identidades WHERE tabla = 'symptom_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "symptom_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'symptom_logs' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_symptom_logs_ai AFTER INSERT ON "symptom_logs" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('symptom_logs', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'symptom_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'sintoma', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'symptom_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'symptom_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'symptom_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_symptom_logs_au AFTER UPDATE OF "date_key", "logged_at", "symptom", "intensity", "notes" ON "symptom_logs" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'symptom_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'sintoma', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'symptom_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'symptom_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'symptom_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_symptom_logs_ad AFTER DELETE ON "symptom_logs" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'symptom_logs' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'symptom_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'sintoma', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'symptom_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'symptom_logs' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'symptom_logs' AND clave = CAST(OLD."id" AS TEXT);
END;

-- vital_readings (signo)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'vital_readings', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "vital_readings";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'signo', registro, 1 FROM sc_sync_identidades WHERE tabla = 'vital_readings';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "vital_readings" f JOIN sc_sync_identidades i
    ON i.tabla = 'vital_readings' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_vital_readings_ai AFTER INSERT ON "vital_readings" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('vital_readings', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'vital_readings' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'signo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'vital_readings' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'vital_readings' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'vital_readings' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_vital_readings_au AFTER UPDATE OF "kind", "measured_at", "date_key", "primary_value", "secondary_value", "context", "source" ON "vital_readings" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'vital_readings' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'signo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'vital_readings' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'vital_readings' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'vital_readings' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_vital_readings_ad AFTER DELETE ON "vital_readings" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'vital_readings' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'vital_readings' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'signo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'vital_readings' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'vital_readings' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'vital_readings' AND clave = CAST(OLD."id" AS TEXT);
END;

-- substance_logs (consumo)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'substance_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "substance_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'consumo', registro, 1 FROM sc_sync_identidades WHERE tabla = 'substance_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "substance_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'substance_logs' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_substance_logs_ai AFTER INSERT ON "substance_logs" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('substance_logs', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'substance_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'consumo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'substance_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'substance_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'substance_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_substance_logs_au AFTER UPDATE OF "date_key", "logged_at", "kind", "preset_key", "standard_drinks", "kcal", "units", "food_log_id" ON "substance_logs" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'substance_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'consumo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'substance_logs' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'substance_logs' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'substance_logs' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_substance_logs_ad AFTER DELETE ON "substance_logs" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'substance_logs' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'substance_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'consumo', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'substance_logs' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'substance_logs' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'substance_logs' AND clave = CAST(OLD."id" AS TEXT);
END;

-- wellbeing_checks (bienestar)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'wellbeing_checks', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "wellbeing_checks";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'bienestar', registro, 1 FROM sc_sync_identidades WHERE tabla = 'wellbeing_checks';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "wellbeing_checks" f JOIN sc_sync_identidades i
    ON i.tabla = 'wellbeing_checks' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_wellbeing_checks_ai AFTER INSERT ON "wellbeing_checks" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('wellbeing_checks', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'wellbeing_checks' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'bienestar', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'wellbeing_checks' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'wellbeing_checks' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'wellbeing_checks' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_wellbeing_checks_au AFTER UPDATE OF "date_key", "created_at", "answers_json", "percent_score" ON "wellbeing_checks" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'wellbeing_checks' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'bienestar', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'wellbeing_checks' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'wellbeing_checks' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'wellbeing_checks' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_wellbeing_checks_ad AFTER DELETE ON "wellbeing_checks" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'wellbeing_checks' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'wellbeing_checks' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'bienestar', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'wellbeing_checks' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'wellbeing_checks' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'wellbeing_checks' AND clave = CAST(OLD."id" AS TEXT);
END;

-- quit_trackers (libre)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'quit_trackers', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "quit_trackers";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'libre', registro, 1 FROM sc_sync_identidades WHERE tabla = 'quit_trackers';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "quit_trackers" f JOIN sc_sync_identidades i
    ON i.tabla = 'quit_trackers' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_quit_trackers_ai AFTER INSERT ON "quit_trackers" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('quit_trackers', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'quit_trackers' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'libre', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'quit_trackers' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'quit_trackers' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'quit_trackers' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_quit_trackers_au AFTER UPDATE OF "preset_key", "custom_name", "started_at", "first_started_at", "longest_streak_seconds", "banked_seconds", "daily_cost", "daily_units", "daily_minutes", "motivation", "celebrated_milestones", "is_archived", "created_at" ON "quit_trackers" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'quit_trackers' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'libre', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'quit_trackers' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'quit_trackers' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'quit_trackers' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_quit_trackers_ad AFTER DELETE ON "quit_trackers" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'quit_trackers' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'quit_trackers' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'libre', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'quit_trackers' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'quit_trackers' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'quit_trackers' AND clave = CAST(OLD."id" AS TEXT);
END;

-- quit_events (evento_libre)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'quit_events', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "quit_events";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'evento_libre', registro, 1 FROM sc_sync_identidades WHERE tabla = 'quit_events';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "quit_events" f JOIN sc_sync_identidades i
    ON i.tabla = 'quit_events' AND i.clave = CAST(f."id" AS TEXT);
CREATE TRIGGER sc_sync_quit_events_ai AFTER INSERT ON "quit_events" BEGIN
    INSERT INTO sc_sync_identidades (tabla, clave, registro)
        VALUES ('quit_events', CAST(NEW."id" AS TEXT),
            coalesce((SELECT registro FROM sc_sync_control WHERE id = 1), lower(hex(randomblob(16)))))
        ON CONFLICT (tabla, clave) DO UPDATE SET eliminado = 0;
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'quit_events' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'evento_libre', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'quit_events' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'quit_events' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'quit_events' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_quit_events_au AFTER UPDATE OF "tracker_id", "kind", "occurred_at", "streak_seconds", "note" ON "quit_events" BEGIN
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'quit_events' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'evento_libre', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'quit_events' AND clave = CAST(NEW."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'quit_events' AND clave = CAST(NEW."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'quit_events' AND clave = CAST(NEW."id" AS TEXT);
END;
CREATE TRIGGER sc_sync_quit_events_ad AFTER DELETE ON "quit_events" BEGIN
    UPDATE sc_sync_identidades SET eliminado = 1 WHERE tabla = 'quit_events' AND clave = CAST(OLD."id" AS TEXT);
    UPDATE sc_sync_identidades SET en_conflicto = 0
        WHERE tabla = 'quit_events' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0;
    INSERT INTO sc_sync_revisiones (entidad, registro, revision)
        SELECT 'evento_libre', registro, compartida + 1 FROM sc_sync_identidades
        WHERE tabla = 'quit_events' AND clave = CAST(OLD."id" AS TEXT) AND (SELECT aplicando FROM sc_sync_control WHERE id = 1) = 0
        ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision;
    DELETE FROM sc_sync_diario WHERE registro = (SELECT registro FROM sc_sync_identidades WHERE tabla = 'quit_events' AND clave = CAST(OLD."id" AS TEXT));
    INSERT INTO sc_sync_diario (registro, origen)
        SELECT registro, (SELECT origen FROM sc_sync_control WHERE id = 1) FROM sc_sync_identidades
        WHERE tabla = 'quit_events' AND clave = CAST(OLD."id" AS TEXT);
END;
''';

/// Identidades nuevas para una base del esquema 8 restaurada.
const String reconstruirSincronizacionV1 = r'''
-- Generado por scripts/generar-sincronizacion.mjs. No se edita a mano.
-- Asigna identidades nuevas a una base del esquema 8 restaurada o migrada al 9.

-- user_profiles (perfil)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'user_profiles', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "user_profiles";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'perfil', registro, 1 FROM sc_sync_identidades WHERE tabla = 'user_profiles';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "user_profiles" f JOIN sc_sync_identidades i
    ON i.tabla = 'user_profiles' AND i.clave = CAST(f."id" AS TEXT);

-- pet_status (inventario_nibi)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'pet_status', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "pet_status";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'inventario_nibi', registro, 1 FROM sc_sync_identidades WHERE tabla = 'pet_status';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "pet_status" f JOIN sc_sync_identidades i
    ON i.tabla = 'pet_status' AND i.clave = CAST(f."id" AS TEXT);

-- daily_summaries (descanso)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'daily_summaries', CAST("date_key" AS TEXT), lower(hex(randomblob(16))) FROM "daily_summaries";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'descanso', registro, 1 FROM sc_sync_identidades WHERE tabla = 'daily_summaries';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "daily_summaries" f JOIN sc_sync_identidades i
    ON i.tabla = 'daily_summaries' AND i.clave = CAST(f."date_key" AS TEXT);

-- food_items (alimento)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'food_items', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "food_items";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'alimento', registro, 1 FROM sc_sync_identidades WHERE tabla = 'food_items';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "food_items" f JOIN sc_sync_identidades i
    ON i.tabla = 'food_items' AND i.clave = CAST(f."id" AS TEXT) WHERE f.source <> 'usda_seed';

-- meal_combos (combo)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'meal_combos', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "meal_combos";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'combo', registro, 1 FROM sc_sync_identidades WHERE tabla = 'meal_combos';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "meal_combos" f JOIN sc_sync_identidades i
    ON i.tabla = 'meal_combos' AND i.clave = CAST(f."id" AS TEXT);

-- meal_combo_items (combo_alimento)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'meal_combo_items', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "meal_combo_items";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'combo_alimento', registro, 1 FROM sc_sync_identidades WHERE tabla = 'meal_combo_items';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "meal_combo_items" f JOIN sc_sync_identidades i
    ON i.tabla = 'meal_combo_items' AND i.clave = CAST(f."id" AS TEXT);

-- recipes (receta)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'recipes', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "recipes";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'receta', registro, 1 FROM sc_sync_identidades WHERE tabla = 'recipes';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "recipes" f JOIN sc_sync_identidades i
    ON i.tabla = 'recipes' AND i.clave = CAST(f."id" AS TEXT);

-- recipe_ingredients (ingrediente)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'recipe_ingredients', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "recipe_ingredients";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'ingrediente', registro, 1 FROM sc_sync_identidades WHERE tabla = 'recipe_ingredients';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "recipe_ingredients" f JOIN sc_sync_identidades i
    ON i.tabla = 'recipe_ingredients' AND i.clave = CAST(f."id" AS TEXT);

-- food_logs (comida)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'food_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "food_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'comida', registro, 1 FROM sc_sync_identidades WHERE tabla = 'food_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "food_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'food_logs' AND i.clave = CAST(f."id" AS TEXT);

-- hydration_logs (agua)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'hydration_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "hydration_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'agua', registro, 1 FROM sc_sync_identidades WHERE tabla = 'hydration_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "hydration_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'hydration_logs' AND i.clave = CAST(f."id" AS TEXT);

-- body_measurements (peso)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'body_measurements', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "body_measurements";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'peso', registro, 1 FROM sc_sync_identidades WHERE tabla = 'body_measurements';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "body_measurements" f JOIN sc_sync_identidades i
    ON i.tabla = 'body_measurements' AND i.clave = CAST(f."id" AS TEXT);

-- workout_blocks (entrenamiento)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'workout_blocks', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "workout_blocks";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'entrenamiento', registro, 1 FROM sc_sync_identidades WHERE tabla = 'workout_blocks';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "workout_blocks" f JOIN sc_sync_identidades i
    ON i.tabla = 'workout_blocks' AND i.clave = CAST(f."id" AS TEXT);

-- fasting_sessions (ayuno)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'fasting_sessions', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "fasting_sessions";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'ayuno', registro, 1 FROM sc_sync_identidades WHERE tabla = 'fasting_sessions';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "fasting_sessions" f JOIN sc_sync_identidades i
    ON i.tabla = 'fasting_sessions' AND i.clave = CAST(f."id" AS TEXT);

-- journal_entries (diario)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'journal_entries', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "journal_entries";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'diario', registro, 1 FROM sc_sync_identidades WHERE tabla = 'journal_entries';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "journal_entries" f JOIN sc_sync_identidades i
    ON i.tabla = 'journal_entries' AND i.clave = CAST(f."id" AS TEXT);

-- coin_ledger (accion_nibi)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'coin_ledger', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "coin_ledger";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'accion_nibi', registro, 1 FROM sc_sync_identidades WHERE tabla = 'coin_ledger';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "coin_ledger" f JOIN sc_sync_identidades i
    ON i.tabla = 'coin_ledger' AND i.clave = CAST(f."id" AS TEXT);

-- supplements_tracker (tratamiento)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'supplements_tracker', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "supplements_tracker";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'tratamiento', registro, 1 FROM sc_sync_identidades WHERE tabla = 'supplements_tracker';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "supplements_tracker" f JOIN sc_sync_identidades i
    ON i.tabla = 'supplements_tracker' AND i.clave = CAST(f."id" AS TEXT);

-- supplement_logs (toma)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'supplement_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "supplement_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'toma', registro, 1 FROM sc_sync_identidades WHERE tabla = 'supplement_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "supplement_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'supplement_logs' AND i.clave = CAST(f."id" AS TEXT);

-- female_cycle_logs (ciclo)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'female_cycle_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "female_cycle_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'ciclo', registro, 1 FROM sc_sync_identidades WHERE tabla = 'female_cycle_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "female_cycle_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'female_cycle_logs' AND i.clave = CAST(f."id" AS TEXT);

-- digestive_logs (digestion)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'digestive_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "digestive_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'digestion', registro, 1 FROM sc_sync_identidades WHERE tabla = 'digestive_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "digestive_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'digestive_logs' AND i.clave = CAST(f."id" AS TEXT);

-- caffeine_logs (cafeina)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'caffeine_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "caffeine_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'cafeina', registro, 1 FROM sc_sync_identidades WHERE tabla = 'caffeine_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "caffeine_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'caffeine_logs' AND i.clave = CAST(f."id" AS TEXT);

-- protocol_plans (plan)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'protocol_plans', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "protocol_plans";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'plan', registro, 1 FROM sc_sync_identidades WHERE tabla = 'protocol_plans';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "protocol_plans" f JOIN sc_sync_identidades i
    ON i.tabla = 'protocol_plans' AND i.clave = CAST(f."id" AS TEXT);

-- milestone_goals (meta)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'milestone_goals', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "milestone_goals";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'meta', registro, 1 FROM sc_sync_identidades WHERE tabla = 'milestone_goals';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "milestone_goals" f JOIN sc_sync_identidades i
    ON i.tabla = 'milestone_goals' AND i.clave = CAST(f."id" AS TEXT);

-- care_sessions (sesion_cuidado)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'care_sessions', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "care_sessions";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'sesion_cuidado', registro, 1 FROM sc_sync_identidades WHERE tabla = 'care_sessions';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "care_sessions" f JOIN sc_sync_identidades i
    ON i.tabla = 'care_sessions' AND i.clave = CAST(f."id" AS TEXT);

-- custom_habits (habito)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'custom_habits', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "custom_habits";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'habito', registro, 1 FROM sc_sync_identidades WHERE tabla = 'custom_habits';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "custom_habits" f JOIN sc_sync_identidades i
    ON i.tabla = 'custom_habits' AND i.clave = CAST(f."id" AS TEXT);

-- habit_logs (habito_hecho)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'habit_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "habit_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'habito_hecho', registro, 1 FROM sc_sync_identidades WHERE tabla = 'habit_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "habit_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'habit_logs' AND i.clave = CAST(f."id" AS TEXT);

-- checkups (chequeo)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'checkups', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "checkups";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'chequeo', registro, 1 FROM sc_sync_identidades WHERE tabla = 'checkups';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "checkups" f JOIN sc_sync_identidades i
    ON i.tabla = 'checkups' AND i.clave = CAST(f."id" AS TEXT);

-- checkup_logs (chequeo_hecho)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'checkup_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "checkup_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'chequeo_hecho', registro, 1 FROM sc_sync_identidades WHERE tabla = 'checkup_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "checkup_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'checkup_logs' AND i.clave = CAST(f."id" AS TEXT);

-- symptom_logs (sintoma)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'symptom_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "symptom_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'sintoma', registro, 1 FROM sc_sync_identidades WHERE tabla = 'symptom_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "symptom_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'symptom_logs' AND i.clave = CAST(f."id" AS TEXT);

-- vital_readings (signo)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'vital_readings', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "vital_readings";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'signo', registro, 1 FROM sc_sync_identidades WHERE tabla = 'vital_readings';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "vital_readings" f JOIN sc_sync_identidades i
    ON i.tabla = 'vital_readings' AND i.clave = CAST(f."id" AS TEXT);

-- substance_logs (consumo)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'substance_logs', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "substance_logs";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'consumo', registro, 1 FROM sc_sync_identidades WHERE tabla = 'substance_logs';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "substance_logs" f JOIN sc_sync_identidades i
    ON i.tabla = 'substance_logs' AND i.clave = CAST(f."id" AS TEXT);

-- wellbeing_checks (bienestar)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'wellbeing_checks', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "wellbeing_checks";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'bienestar', registro, 1 FROM sc_sync_identidades WHERE tabla = 'wellbeing_checks';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "wellbeing_checks" f JOIN sc_sync_identidades i
    ON i.tabla = 'wellbeing_checks' AND i.clave = CAST(f."id" AS TEXT);

-- quit_trackers (libre)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'quit_trackers', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "quit_trackers";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'libre', registro, 1 FROM sc_sync_identidades WHERE tabla = 'quit_trackers';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "quit_trackers" f JOIN sc_sync_identidades i
    ON i.tabla = 'quit_trackers' AND i.clave = CAST(f."id" AS TEXT);

-- quit_events (evento_libre)
INSERT INTO sc_sync_identidades (tabla, clave, registro)
    SELECT 'quit_events', CAST("id" AS TEXT), lower(hex(randomblob(16))) FROM "quit_events";
INSERT INTO sc_sync_revisiones (entidad, registro, revision)
    SELECT 'evento_libre', registro, 1 FROM sc_sync_identidades WHERE tabla = 'quit_events';
INSERT INTO sc_sync_diario (registro)
    SELECT i.registro FROM "quit_events" f JOIN sc_sync_identidades i
    ON i.tabla = 'quit_events' AND i.clave = CAST(f."id" AS TEXT);
''';

/// Columnas, referencias y claves naturales de cada tabla compartida.
const String adaptadoresSincronizacionV1 = r'''
{
  "version": 1,
  "tablas": [
    {
      "tabla": "user_profiles",
      "entidad": "perfil",
      "clave": "id",
      "unico": true,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "name",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "birth_date",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "biological_sex",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "height_cm",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "target_weight_kg",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "weekly_goal_rate_kg",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "daily_water_goal_ml",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "daily_steps_goal",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "daily_sleep_goal_hours",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "is_cycle_tracking_enabled",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "is_fasting_enabled",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "is_manual_macro_mode",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "manual_kcal_target",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "manual_protein_g",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "manual_carbs_g",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "manual_fat_g",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "active_diet_archetype",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "active_diet_phase",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "calorie_cycling_schedule_json",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "caffeine_bedtime_cutoff_hours",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "active_diet_phase_started_at",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "has_impedance_contraindication",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "has_eating_disorder_history",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "takes_hypoglycemic_medication",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "target_bedtime_minutes",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "created_at",
          "tipo": "texto",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "pet_status",
      "entidad": "inventario_nibi",
      "clave": "id",
      "unico": true,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "pet_name",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "equipped_hat_id",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "equipped_accessory_id",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "equipped_color_id",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "equipped_background_id",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "unlocked_items_json",
          "tipo": "texto",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "daily_summaries",
      "entidad": "descanso",
      "clave": "date_key",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "steps_count",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "active_calories_from_steps",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "sleep_duration_minutes",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "sleep_deep_minutes",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "sleep_rem_minutes",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "resting_heart_rate_bpm",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "wake_time_minutes",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "calorie_target_kcal",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "protein_target_g",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "carbs_target_g",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "fat_target_g",
          "tipo": "entero",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "date_key"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "food_items",
      "entidad": "alimento",
      "clave": "id",
      "unico": false,
      "publicar_si": "source <> 'usda_seed'",
      "columnas": [
        {
          "nombre": "barcode",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "name",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "brand",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "source",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "nutri_score",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "nova_group",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "default_serving_grams",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "serving_label",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "kcal_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "protein_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "carbs_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "fat_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "fiber_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "sugar_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "sodium_mg_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "potassium_mg_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "magnesium_mg_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "calcium_mg_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "iron_mg_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "zinc_mg_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "vitamin_c_mg_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "vitamin_d_ug_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "vitamin_b12_ug_per100g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "is_favorite",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "last_used_at",
          "tipo": "texto",
          "nulo": true
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "barcode"
          ],
          "excepto": {}
        },
        {
          "columnas": [
            "name",
            "brand",
            "source",
            "kcal_per100g"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "meal_combos",
      "entidad": "combo",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "name",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "default_meal_type",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "times_used",
          "tipo": "entero",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "name"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "meal_combo_items",
      "entidad": "combo_alimento",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "combo_id",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "food_item_id",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "base_grams",
          "tipo": "real",
          "nulo": false
        }
      ],
      "referencias": {
        "combo_id": "meal_combos",
        "food_item_id": "food_items"
      },
      "natural": [
        {
          "columnas": [
            "combo_id",
            "food_item_id",
            "base_grams"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "recipes",
      "entidad": "receta",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "name",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "description",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "default_meal_type",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "total_yield_servings",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "cooked_total_weight_grams",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "kcal_per_serving",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "protein_per_serving",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "carbs_per_serving",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "fat_per_serving",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "fiber_per_serving",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "sodium_mg_per_serving",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "potassium_mg_per_serving",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "magnesium_mg_per_serving",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "created_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "last_used_at",
          "tipo": "texto",
          "nulo": true
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "name",
            "created_at"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "recipe_ingredients",
      "entidad": "ingrediente",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "recipe_id",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "food_item_id",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "raw_grams",
          "tipo": "real",
          "nulo": false
        }
      ],
      "referencias": {
        "recipe_id": "recipes",
        "food_item_id": "food_items"
      },
      "natural": [
        {
          "columnas": [
            "recipe_id",
            "food_item_id",
            "raw_grams"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "food_logs",
      "entidad": "comida",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "logged_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "meal_type",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "food_item_id",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "grams_consumed",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "portion_multiplier",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "total_kcal",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "total_protein_g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "total_carbs_g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "total_fat_g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "total_fiber_g",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "total_sodium_mg",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "total_potassium_mg",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "total_magnesium_mg",
          "tipo": "real",
          "nulo": false
        }
      ],
      "referencias": {
        "food_item_id": "food_items"
      },
      "natural": [
        {
          "columnas": [
            "logged_at",
            "food_item_id",
            "grams_consumed"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "hydration_logs",
      "entidad": "agua",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "logged_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "volume_ml",
          "tipo": "entero",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "logged_at",
            "volume_ml"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "body_measurements",
      "entidad": "peso",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "measured_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "source",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "weight_kg",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "trend_weight_kg",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "impedance_ohms",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "bmi",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "body_fat_percentage",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "muscle_mass_kg",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "water_percentage",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "visceral_fat_index",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "bone_mass_kg",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "protein_percentage",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "basal_metabolic_rate_kcal",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "metabolic_age",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "lean_body_mass_kg",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "body_score",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "somatotype",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "waist_cm",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "neck_cm",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "hip_cm",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "validated_body_fat_percentage",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "is_water_retention_spike",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "spike_explanation",
          "tipo": "texto",
          "nulo": true
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "measured_at"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "workout_blocks",
      "entidad": "entrenamiento",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "performed_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "category",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "duration_minutes",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "rpe_intensity",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "applied_met",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "user_weight_at_time_kg",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "net_calories_burned",
          "tipo": "entero",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "performed_at",
            "category"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "fasting_sessions",
      "entidad": "ayuno",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "protocol_name",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "target_hours",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "started_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "planned_end_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "actual_ended_at",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "is_completed",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "notes",
          "tipo": "texto",
          "nulo": true
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "started_at"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "journal_entries",
      "entidad": "diario",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "created_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "content",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "mood_score",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "energy_level",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "stress_level",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "tags_json",
          "tipo": "texto",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "created_at"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "coin_ledger",
      "entidad": "accion_nibi",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "created_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "action_type",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "amount",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "sleep_multiplier_applied",
          "tipo": "real",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "created_at",
            "action_type",
            "amount"
          ],
          "excepto": {}
        },
        {
          "excepto": {
            "action_type": "shop_buy"
          },
          "columnas": [
            "date_key",
            "action_type"
          ]
        }
      ]
    },
    {
      "tabla": "supplements_tracker",
      "entidad": "tratamiento",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "name",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "dosage",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "target_time_of_day_minutes",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "affects_water_retention",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "is_enabled",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "created_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "kind",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "schedule_json",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "days_of_week_bitmask",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "stock_units",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "units_per_dose",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "reminders_enabled",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "lowers_glucose",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "notes",
          "tipo": "texto",
          "nulo": true
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "name",
            "created_at"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "supplement_logs",
      "entidad": "toma",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "supplement_id",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "taken_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "was_taken",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "slot_minutes",
          "tipo": "entero",
          "nulo": true
        }
      ],
      "referencias": {
        "supplement_id": "supplements_tracker"
      },
      "natural": [
        {
          "columnas": [
            "supplement_id",
            "date_key",
            "slot_minutes"
          ],
          "excepto": {}
        },
        {
          "columnas": [
            "supplement_id",
            "taken_at"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "female_cycle_logs",
      "entidad": "ciclo",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "cycle_start_date",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "cycle_end_date",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "cycle_length_days",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "flow_intensity",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "symptoms_json",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "notes",
          "tipo": "texto",
          "nulo": true
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "cycle_start_date"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "digestive_logs",
      "entidad": "digestion",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "logged_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "bristol_type",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "discomfort_level",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "symptoms_json",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "notes",
          "tipo": "texto",
          "nulo": true
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "logged_at"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "caffeine_logs",
      "entidad": "cafeina",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "logged_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "source_name",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "caffeine_mg",
          "tipo": "real",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "logged_at",
            "source_name"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "protocol_plans",
      "entidad": "plan",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "plan_name",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "fasting_days_bitmask",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "workout_slots_json",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "diet_archetype",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "is_current_active",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "updated_at",
          "tipo": "texto",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "plan_name"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "milestone_goals",
      "entidad": "meta",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "milestone_order",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "target_weight_kg",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "is_completed",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "completed_at",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "estimated_completion_date",
          "tipo": "texto",
          "nulo": true
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "milestone_order"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "care_sessions",
      "entidad": "sesion_cuidado",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "completed_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "kind",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "variant",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "duration_seconds",
          "tipo": "entero",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "completed_at",
            "kind"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "custom_habits",
      "entidad": "habito",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "name",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "icon_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "days_of_week_bitmask",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "sort_order",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "is_archived",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "created_at",
          "tipo": "texto",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "name",
            "created_at"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "habit_logs",
      "entidad": "habito_hecho",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "habit_id",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "logged_at",
          "tipo": "texto",
          "nulo": false
        }
      ],
      "referencias": {
        "habit_id": "custom_habits"
      },
      "natural": [
        {
          "columnas": [
            "habit_id",
            "date_key"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "checkups",
      "entidad": "chequeo",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "catalog_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "custom_name",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "interval_months",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "is_enabled",
          "tipo": "booleano",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "catalog_key",
            "custom_name"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "checkup_logs",
      "entidad": "chequeo_hecho",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "checkup_id",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "done_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "notes",
          "tipo": "texto",
          "nulo": true
        }
      ],
      "referencias": {
        "checkup_id": "checkups"
      },
      "natural": [
        {
          "columnas": [
            "checkup_id",
            "done_at"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "symptom_logs",
      "entidad": "sintoma",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "logged_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "symptom",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "intensity",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "notes",
          "tipo": "texto",
          "nulo": true
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "logged_at",
            "symptom"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "vital_readings",
      "entidad": "signo",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "kind",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "measured_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "primary_value",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "secondary_value",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "context",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "source",
          "tipo": "texto",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "kind",
            "measured_at"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "substance_logs",
      "entidad": "consumo",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "logged_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "kind",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "preset_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "standard_drinks",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "kcal",
          "tipo": "real",
          "nulo": false
        },
        {
          "nombre": "units",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "food_log_id",
          "tipo": "entero",
          "nulo": true
        }
      ],
      "referencias": {
        "food_log_id": "food_logs"
      },
      "natural": [
        {
          "columnas": [
            "logged_at",
            "kind"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "wellbeing_checks",
      "entidad": "bienestar",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "date_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "created_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "answers_json",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "percent_score",
          "tipo": "entero",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "created_at"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "quit_trackers",
      "entidad": "libre",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "preset_key",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "custom_name",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "started_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "first_started_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "longest_streak_seconds",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "banked_seconds",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "daily_cost",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "daily_units",
          "tipo": "real",
          "nulo": true
        },
        {
          "nombre": "daily_minutes",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "motivation",
          "tipo": "texto",
          "nulo": true
        },
        {
          "nombre": "celebrated_milestones",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "is_archived",
          "tipo": "booleano",
          "nulo": false
        },
        {
          "nombre": "created_at",
          "tipo": "texto",
          "nulo": false
        }
      ],
      "referencias": {},
      "natural": [
        {
          "columnas": [
            "preset_key",
            "first_started_at"
          ],
          "excepto": {}
        }
      ]
    },
    {
      "tabla": "quit_events",
      "entidad": "evento_libre",
      "clave": "id",
      "unico": false,
      "publicar_si": null,
      "columnas": [
        {
          "nombre": "tracker_id",
          "tipo": "entero",
          "nulo": false
        },
        {
          "nombre": "kind",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "occurred_at",
          "tipo": "texto",
          "nulo": false
        },
        {
          "nombre": "streak_seconds",
          "tipo": "entero",
          "nulo": true
        },
        {
          "nombre": "note",
          "tipo": "texto",
          "nulo": true
        }
      ],
      "referencias": {
        "tracker_id": "quit_trackers"
      },
      "natural": [
        {
          "columnas": [
            "tracker_id",
            "kind",
            "occurred_at"
          ],
          "excepto": {}
        }
      ]
    }
  ]
}
''';

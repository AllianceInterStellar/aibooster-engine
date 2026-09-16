package db

import (
	"bytes"
	"encoding/gob"
	"fmt"
	"log"
	"os"
	"reflect"
	"time"

	"github.com/syndtr/goleveldb/leveldb/opt"
	tmdb "github.com/tendermint/tm-db"
)

// getDB initializes the database with retry logic. If it fails after 100 attempts, it returns nil.
func getDB(name string, readOnly bool) (tmdb.DB, error) {
	// Check if the database file exists; if not, set to readOnly
	dbPath := "data/" + name + ".db"
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		readOnly = false
	}
	const retryAttempts = 100
	const retryDelay = 50 * time.Millisecond

	var db tmdb.DB
	var err error
	defer func() {
		if r := recover(); r != nil {
			log.Printf("Recovered from panic: %v", r)
		}
	}()
	for i := 0; i < retryAttempts; i++ {
		// Set readOnly to true for the first 80 attempts
		opts := &opt.Options{ReadOnly: readOnly && i < 80}

		db, err = tmdb.NewGoLevelDBWithOpts(name, "./data", opts)
		if err == nil {
			return db, nil
		}
		log.Printf("Failed attempt %d to initialize the database: %v", i, err)
		time.Sleep(retryDelay)
	}
	return nil, err
}

// GetTable returns a new Table instance for the generic type T.
// Uses firstExportedFieldIndex instead of FieldByName("Id") to support garble obfuscation.
func GetTable[T any]() *Table[T] {
	var t T
	typeName := reflect.TypeOf(t).Name()
	if firstExportedFieldIndex(t) < 0 {
		panic(fmt.Sprintf("Table %s must have at least one exported field", typeName))
	}
	return &Table[T]{name: typeName}
}

// firstExportedFieldIndex returns the index of the first exported field in a struct, or -1 if none found.
// This replaces FieldByName("Id") to work with garble obfuscation where field names are mangled.
func firstExportedFieldIndex[T any](t T) int {
	val := reflect.Indirect(reflect.ValueOf(t))
	if val.Kind() != reflect.Struct {
		return -1
	}
	for i := 0; i < val.NumField(); i++ {
		if val.Type().Field(i).IsExported() {
			return i
		}
	}
	return -1
}

// getIdBytes converts an ID to its byte representation for storage in the database.
func getIdBytes(id any) []byte {
	res, err := SerializeKey(id)
	if err != nil {
		return nil
	}
	return res
}

// 	if id == nil {
// 		return nil
// 	}

// 	var buf bytes.Buffer
// 	switch v := id.(type) {
// 	case int, int8, int16, int32, int64, uint, uint8, uint16, uint32, uint64:
// 		if err := binary.Write(&buf, binary.BigEndian, v); err == nil {
// 			return buf.Bytes()
// 		}
// 	case string:
// 		return []byte(v)
// 	case []byte:
// 		return v
// 	default:
// 		return []byte(fmt.Sprint(v))
// 	}
// 	return nil
// }

// getId retrieves the Id field (first exported field) from the struct T.
// Uses field index instead of FieldByName to support garble obfuscation.
func getId[T any](t T) any {
	val := reflect.Indirect(reflect.ValueOf(t))

	if val.Kind() != reflect.Struct {
		return nil
	}

	idx := firstExportedFieldIndex(t)
	if idx < 0 {
		return nil
	}
	field := val.Field(idx)
	if field.IsValid() {
		return field.Interface()
	}
	return nil
}

// Table represents a database table for generic type T.
type Table[T any] struct {
	name string
}

// All retrieves all entries from the database and unmarshals them into a slice of T.
func (tbl *Table[T]) All() ([]*T, error) {
	db, err := getDB(tbl.name, true)
	if db == nil {
		return nil, fmt.Errorf("failed to open database %s, error: %w", tbl.name, err)
	}
	defer db.Close()

	var items []*T
	iter, err := db.Iterator(nil, nil)
	if err != nil {
		return nil, err
	}
	defer iter.Close()

	for ; iter.Valid(); iter.Next() {

		item, err := Deserialize[T](iter.Value())
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, nil
}

func Serialize(data any) ([]byte, error) {
	var buf bytes.Buffer
	enc := gob.NewEncoder(&buf)
	err := enc.Encode(data)
	return buf.Bytes(), err

	// return json.Marshal(data)
}

func SerializeKey(data any) ([]byte, error) {
	var buf bytes.Buffer
	enc := gob.NewEncoder(&buf)
	err := enc.Encode(data)
	return buf.Bytes(), err
}

func Deserialize[T any](data []byte) (*T, error) {
	var obj T
	buf := bytes.NewBuffer(data)
	dec := gob.NewDecoder(buf)
	err := dec.Decode(&obj)
	return &obj, err

	// return &obj, json.Unmarshal(data, &obj)
}

// UpdateInsert inserts or updates multiple items in the database.
func (tbl *Table[T]) UpdateInsert(items ...*T) error {
	db, err := getDB(tbl.name, false)
	if db == nil {
		return fmt.Errorf("failed to open database %s, error: %w", tbl.name, err)
	}
	defer db.Close()

	for _, item := range items {
		// b, err := json.Marshal(item)
		b, err := Serialize(item)
		if err != nil {
			return err
		}
		if err := db.Set(getIdBytes(getId(item)), b); err != nil {
			return err
		}
	}
	return nil
}

// Delete removes entries by their IDs.
func (tbl *Table[T]) Delete(ids ...any) error {
	db, err := getDB(tbl.name, false)
	if db == nil {
		return fmt.Errorf("failed to open database %s, error: %w", tbl.name, err)
	}
	defer db.Close()

	for _, id := range ids {
		if err := db.Delete(getIdBytes(id)); err != nil {
			return err
		}
	}
	return nil
}

// Get retrieves a single item by its ID.
func (tbl *Table[T]) Get(id any) (*T, error) {
	db, err := getDB(tbl.name, true)
	if db == nil {
		return nil, fmt.Errorf("failed to open database %s, error: %w", tbl.name, err)
	}
	defer db.Close()

	b, err := db.Get(getIdBytes(id))
	if err != nil {
		return nil, err
	}
	return Deserialize[T](b)
}

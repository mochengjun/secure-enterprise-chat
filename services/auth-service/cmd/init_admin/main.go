package main

import (
	"fmt"
	"log"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

type AdminUser struct {
	UserID    string `gorm:"primaryKey;size:36"`
	Role      string `gorm:"size:20;not null;default:viewer"`
	CreatedAt time.Time
	CreatedBy string `gorm:"size:36"`
}

func main() {
	db, err := gorm.Open(sqlite.Open("./auth.db"), &gorm.Config{})
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	admin := &AdminUser{
		UserID:    "@superadmin:sec-chat.local",
		Role:      "super_admin",
		CreatedAt: time.Now(),
		CreatedBy: "system",
	}

	result := db.Create(admin)
	if result.Error != nil {
		log.Printf("Error (may already exist): %v", result.Error)
	} else {
		fmt.Println("Super admin created successfully!")
	}
}

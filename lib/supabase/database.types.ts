export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      admin_logs: {
        Row: {
          action: string | null
          admin_id: string
          created_at: string | null
          details: string | null
          id: string
          target: string | null
        }
        Insert: {
          action?: string | null
          admin_id: string
          created_at?: string | null
          details?: string | null
          id?: string
          target?: string | null
        }
        Update: {
          action?: string | null
          admin_id?: string
          created_at?: string | null
          details?: string | null
          id?: string
          target?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "admin_logs_admin_id_fkey"
            columns: ["admin_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      admins: {
        Row: {
          id: string
          role: string | null
        }
        Insert: {
          id: string
          role?: string | null
        }
        Update: {
          id?: string
          role?: string | null
        }
        Relationships: []
      }
      applications: {
        Row: {
          created_at: string | null
          id: string
          job_id: string | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          job_id?: string | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          job_id?: string | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "applications_job_id_fkey"
            columns: ["job_id"]
            isOneToOne: false
            referencedRelation: "jobs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "applications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      approvals: {
        Row: {
          created_at: string | null
          id: string
          receiver_id: string | null
          request_type: string | null
          sender_id: string | null
          status: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          receiver_id?: string | null
          request_type?: string | null
          sender_id?: string | null
          status?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          receiver_id?: string | null
          request_type?: string | null
          sender_id?: string | null
          status?: string | null
        }
        Relationships: []
      }
      articles: {
        Row: {
          author_name: string | null
          category: string | null
          content: string | null
          created_at: string | null
          id: string
          image_url: string | null
          is_trending: boolean | null
          title: string
        }
        Insert: {
          author_name?: string | null
          category?: string | null
          content?: string | null
          created_at?: string | null
          id?: string
          image_url?: string | null
          is_trending?: boolean | null
          title: string
        }
        Update: {
          author_name?: string | null
          category?: string | null
          content?: string | null
          created_at?: string | null
          id?: string
          image_url?: string | null
          is_trending?: boolean | null
          title?: string
        }
        Relationships: []
      }
      audit_logs: {
        Row: {
          action: string
          created_at: string | null
          entity: string | null
          entity_id: string | null
          id: string
          ip_address: string | null
          metadata: Json | null
          user_agent: string | null
          user_id: string | null
        }
        Insert: {
          action: string
          created_at?: string | null
          entity?: string | null
          entity_id?: string | null
          id?: string
          ip_address?: string | null
          metadata?: Json | null
          user_agent?: string | null
          user_id?: string | null
        }
        Update: {
          action?: string
          created_at?: string | null
          entity?: string | null
          entity_id?: string | null
          id?: string
          ip_address?: string | null
          metadata?: Json | null
          user_agent?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      blood_requests: {
        Row: {
          blood_type: string | null
          created_at: string | null
          id: number
          latitude: number | null
          longitude: number | null
          type: string | null
          user_id: string | null
        }
        Insert: {
          blood_type?: string | null
          created_at?: string | null
          id?: number
          latitude?: number | null
          longitude?: number | null
          type?: string | null
          user_id?: string | null
        }
        Update: {
          blood_type?: string | null
          created_at?: string | null
          id?: number
          latitude?: number | null
          longitude?: number | null
          type?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      blood_services: {
        Row: {
          blood_type: string
          created_at: string | null
          id: string
          location: unknown
          service_type: string | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          blood_type: string
          created_at?: string | null
          id?: string
          location?: unknown
          service_type?: string | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          blood_type?: string
          created_at?: string | null
          id?: string
          location?: unknown
          service_type?: string | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "blood_services_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      call_history: {
        Row: {
          call_type: string | null
          caller_id: string | null
          created_at: string | null
          duration_seconds: number | null
          id: string
          receiver_id: string | null
          room_id: string | null
          status: string | null
        }
        Insert: {
          call_type?: string | null
          caller_id?: string | null
          created_at?: string | null
          duration_seconds?: number | null
          id?: string
          receiver_id?: string | null
          room_id?: string | null
          status?: string | null
        }
        Update: {
          call_type?: string | null
          caller_id?: string | null
          created_at?: string | null
          duration_seconds?: number | null
          id?: string
          receiver_id?: string | null
          room_id?: string | null
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "call_history_caller_id_fkey"
            columns: ["caller_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "call_history_receiver_id_fkey"
            columns: ["receiver_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      calls: {
        Row: {
          caller_id: string
          channel_id: string | null
          created_at: string | null
          id: string
          receiver_id: string | null
          status: string | null
          type: string | null
        }
        Insert: {
          caller_id: string
          channel_id?: string | null
          created_at?: string | null
          id?: string
          receiver_id?: string | null
          status?: string | null
          type?: string | null
        }
        Update: {
          caller_id?: string
          channel_id?: string | null
          created_at?: string | null
          id?: string
          receiver_id?: string | null
          status?: string | null
          type?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "calls_caller_id_fkey"
            columns: ["caller_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "calls_receiver_id_fkey"
            columns: ["receiver_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      certifications: {
        Row: {
          created_at: string | null
          file_url: string | null
          id: string
          is_public: boolean | null
          is_verified: boolean | null
          issue_date: string | null
          issuer: string | null
          title: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          file_url?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          issue_date?: string | null
          issuer?: string | null
          title?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          file_url?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          issue_date?: string | null
          issuer?: string | null
          title?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "certifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_messages: {
        Row: {
          content: string
          created_at: string | null
          id: string
          room_id: string | null
          sender_id: string | null
        }
        Insert: {
          content: string
          created_at?: string | null
          id?: string
          room_id?: string | null
          sender_id?: string | null
        }
        Update: {
          content?: string
          created_at?: string | null
          id?: string
          room_id?: string | null
          sender_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "chat_messages_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "chat_rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_participants: {
        Row: {
          chat_id: string
          user_id: string
        }
        Insert: {
          chat_id: string
          user_id: string
        }
        Update: {
          chat_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "chat_participants_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_participants_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_rooms: {
        Row: {
          id: string
          last_message: string | null
          participant_a: string | null
          participant_b: string | null
          updated_at: string | null
        }
        Insert: {
          id?: string
          last_message?: string | null
          participant_a?: string | null
          participant_b?: string | null
          updated_at?: string | null
        }
        Update: {
          id?: string
          last_message?: string | null
          participant_a?: string | null
          participant_b?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "chat_rooms_participant_a_fkey"
            columns: ["participant_a"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_rooms_participant_b_fkey"
            columns: ["participant_b"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      chats: {
        Row: {
          chat_id: string
          content: string | null
          created_at: string | null
          id: string
          is_read: boolean | null
          sender_id: string | null
        }
        Insert: {
          chat_id: string
          content?: string | null
          created_at?: string | null
          id?: string
          is_read?: boolean | null
          sender_id?: string | null
        }
        Update: {
          chat_id?: string
          content?: string | null
          created_at?: string | null
          id?: string
          is_read?: boolean | null
          sender_id?: string | null
        }
        Relationships: []
      }
      communes: {
        Row: {
          id: string
          name: string
          ville_id: string | null
        }
        Insert: {
          id?: string
          name: string
          ville_id?: string | null
        }
        Update: {
          id?: string
          name?: string
          ville_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "communes_ville_id_fkey"
            columns: ["ville_id"]
            isOneToOne: false
            referencedRelation: "villes"
            referencedColumns: ["id"]
          },
        ]
      }
      companies: {
        Row: {
          created_at: string | null
          description: string | null
          id: string
          industry: string | null
          name: string
          owner_id: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          id?: string
          industry?: string | null
          name: string
          owner_id?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          id?: string
          industry?: string | null
          name?: string
          owner_id?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "companies_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      company_members: {
        Row: {
          company_id: string | null
          created_at: string | null
          id: string
          role: string | null
          user_id: string | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          id?: string
          role?: string | null
          user_id?: string | null
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          id?: string
          role?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "company_members_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "company_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      connections: {
        Row: {
          created_at: string | null
          id: string
          status: string
          user1_id: string
          user2_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          status?: string
          user1_id: string
          user2_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          status?: string
          user1_id?: string
          user2_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "connections_user1_id_fkey"
            columns: ["user1_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "connections_user2_id_fkey"
            columns: ["user2_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      contacts_urgence: {
        Row: {
          created_at: string | null
          id: string
          nom: string | null
          relation: string | null
          telephone: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          nom?: string | null
          relation?: string | null
          telephone?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          nom?: string | null
          relation?: string | null
          telephone?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      documents: {
        Row: {
          created_at: string | null
          doc_id: string | null
          doc_type: string | null
          document_type: string | null
          file_path: string | null
          file_url: string | null
          id: string
          is_public: boolean | null
          is_verified: boolean | null
          mime_type: string | null
          status: string | null
          storage_path: string | null
          title: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          doc_id?: string | null
          doc_type?: string | null
          document_type?: string | null
          file_path?: string | null
          file_url?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          mime_type?: string | null
          status?: string | null
          storage_path?: string | null
          title?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          doc_id?: string | null
          doc_type?: string | null
          document_type?: string | null
          file_path?: string | null
          file_url?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          mime_type?: string | null
          status?: string | null
          storage_path?: string | null
          title?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "documents_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      education: {
        Row: {
          city: string | null
          created_at: string | null
          date_debut: string | null
          date_fin: string | null
          degree: string | null
          diploma: string | null
          establishment: string | null
          field_of_study: string | null
          id: string
          is_public: boolean | null
          is_verified: boolean | null
          period: string | null
          school_name: string | null
          user_id: string | null
        }
        Insert: {
          city?: string | null
          created_at?: string | null
          date_debut?: string | null
          date_fin?: string | null
          degree?: string | null
          diploma?: string | null
          establishment?: string | null
          field_of_study?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          period?: string | null
          school_name?: string | null
          user_id?: string | null
        }
        Update: {
          city?: string | null
          created_at?: string | null
          date_debut?: string | null
          date_fin?: string | null
          degree?: string | null
          diploma?: string | null
          establishment?: string | null
          field_of_study?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          period?: string | null
          school_name?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "education_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      emergency_alerts: {
        Row: {
          audio_record_url: string | null
          created_at: string | null
          id: string
          is_silent: boolean | null
          location_gps: unknown
          status: string | null
          type: string
          user_id: string | null
        }
        Insert: {
          audio_record_url?: string | null
          created_at?: string | null
          id?: string
          is_silent?: boolean | null
          location_gps?: unknown
          status?: string | null
          type: string
          user_id?: string | null
        }
        Update: {
          audio_record_url?: string | null
          created_at?: string | null
          id?: string
          is_silent?: boolean | null
          location_gps?: unknown
          status?: string | null
          type?: string
          user_id?: string | null
        }
        Relationships: []
      }
      emergency_audio_logs: {
        Row: {
          alert_id: number | null
          created_at: string | null
          file_url: string | null
          id: number
        }
        Insert: {
          alert_id?: number | null
          created_at?: string | null
          file_url?: string | null
          id?: number
        }
        Update: {
          alert_id?: number | null
          created_at?: string | null
          file_url?: string | null
          id?: number
        }
        Relationships: []
      }
      emergency_audit_logs: {
        Row: {
          action: string | null
          created_at: string | null
          id: number
          metadata: Json | null
          user_id: string | null
        }
        Insert: {
          action?: string | null
          created_at?: string | null
          id?: number
          metadata?: Json | null
          user_id?: string | null
        }
        Update: {
          action?: string | null
          created_at?: string | null
          id?: number
          metadata?: Json | null
          user_id?: string | null
        }
        Relationships: []
      }
      emergency_contacts: {
        Row: {
          city: string | null
          id: string
          name: string | null
          phone: string | null
          relation: string | null
          user_id: string | null
        }
        Insert: {
          city?: string | null
          id?: string
          name?: string | null
          phone?: string | null
          relation?: string | null
          user_id?: string | null
        }
        Update: {
          city?: string | null
          id?: string
          name?: string | null
          phone?: string | null
          relation?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "emergency_contacts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      emergency_notifications: {
        Row: {
          alert_id: number | null
          created_at: string | null
          id: number
          message: string | null
          recipient_id: string | null
          status: string | null
        }
        Insert: {
          alert_id?: number | null
          created_at?: string | null
          id?: number
          message?: string | null
          recipient_id?: string | null
          status?: string | null
        }
        Update: {
          alert_id?: number | null
          created_at?: string | null
          id?: number
          message?: string | null
          recipient_id?: string | null
          status?: string | null
        }
        Relationships: []
      }
      emergency_services: {
        Row: {
          id: number
          name: string | null
          phone: string | null
          type: string | null
        }
        Insert: {
          id?: number
          name?: string | null
          phone?: string | null
          type?: string | null
        }
        Update: {
          id?: number
          name?: string | null
          phone?: string | null
          type?: string | null
        }
        Relationships: []
      }
      emergency_tracking: {
        Row: {
          alert_id: number | null
          created_at: string | null
          id: number
          latitude: number | null
          longitude: number | null
        }
        Insert: {
          alert_id?: number | null
          created_at?: string | null
          id?: number
          latitude?: number | null
          longitude?: number | null
        }
        Update: {
          alert_id?: number | null
          created_at?: string | null
          id?: number
          latitude?: number | null
          longitude?: number | null
        }
        Relationships: []
      }
      experience: {
        Row: {
          company_name: string | null
          created_at: string | null
          description: string | null
          end_date: string | null
          id: string
          is_public: boolean | null
          is_verified: boolean | null
          position: string | null
          start_date: string | null
          user_id: string | null
        }
        Insert: {
          company_name?: string | null
          created_at?: string | null
          description?: string | null
          end_date?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          position?: string | null
          start_date?: string | null
          user_id?: string | null
        }
        Update: {
          company_name?: string | null
          created_at?: string | null
          description?: string | null
          end_date?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          position?: string | null
          start_date?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "experience_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      experiences: {
        Row: {
          company: string | null
          company_name: string | null
          created_at: string | null
          description: string | null
          employer: string | null
          entreprise: string | null
          id: string
          missions: string | null
          position: string | null
          secteur: string | null
          titre_poste: string | null
          user_id: string | null
          ville: string | null
        }
        Insert: {
          company?: string | null
          company_name?: string | null
          created_at?: string | null
          description?: string | null
          employer?: string | null
          entreprise?: string | null
          id?: string
          missions?: string | null
          position?: string | null
          secteur?: string | null
          titre_poste?: string | null
          user_id?: string | null
          ville?: string | null
        }
        Update: {
          company?: string | null
          company_name?: string | null
          created_at?: string | null
          description?: string | null
          employer?: string | null
          entreprise?: string | null
          id?: string
          missions?: string | null
          position?: string | null
          secteur?: string | null
          titre_poste?: string | null
          user_id?: string | null
          ville?: string | null
        }
        Relationships: []
      }
      formations: {
        Row: {
          duration: string | null
          end_date: string | null
          id: string
          organizer: string | null
          skills: string | null
          start_date: string | null
          title: string | null
          type: string | null
          user_id: string | null
        }
        Insert: {
          duration?: string | null
          end_date?: string | null
          id?: string
          organizer?: string | null
          skills?: string | null
          start_date?: string | null
          title?: string | null
          type?: string | null
          user_id?: string | null
        }
        Update: {
          duration?: string | null
          end_date?: string | null
          id?: string
          organizer?: string | null
          skills?: string | null
          start_date?: string | null
          title?: string | null
          type?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "formations_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      fraud_logs: {
        Row: {
          created_at: string | null
          id: string
          metadata: Json | null
          reason: string | null
          risk_level: string | null
          risk_score: number | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          metadata?: Json | null
          reason?: string | null
          risk_level?: string | null
          risk_score?: number | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          metadata?: Json | null
          reason?: string | null
          risk_level?: string | null
          risk_score?: number | null
          user_id?: string | null
        }
        Relationships: []
      }
      identity_verification: {
        Row: {
          ai_score: number | null
          created_at: string | null
          document_type: string | null
          document_url: string
          id: string
          status: string | null
          user_id: string | null
          verified_at: string | null
        }
        Insert: {
          ai_score?: number | null
          created_at?: string | null
          document_type?: string | null
          document_url: string
          id?: string
          status?: string | null
          user_id?: string | null
          verified_at?: string | null
        }
        Update: {
          ai_score?: number | null
          created_at?: string | null
          document_type?: string | null
          document_url?: string
          id?: string
          status?: string | null
          user_id?: string | null
          verified_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "identity_verification_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      jobs: {
        Row: {
          company_id: string | null
          created_at: string | null
          description: string | null
          id: string
          posted_by: string | null
          title: string
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          posted_by?: string | null
          title: string
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          posted_by?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "jobs_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "jobs_posted_by_fkey"
            columns: ["posted_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      languages: {
        Row: {
          created_at: string | null
          id: string
          language_name: string | null
          proficiency_level: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          language_name?: string | null
          proficiency_level?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          language_name?: string | null
          proficiency_level?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      locations: {
        Row: {
          city: string | null
          commune: string | null
          id: string
          province: string | null
          territory: string | null
        }
        Insert: {
          city?: string | null
          commune?: string | null
          id?: string
          province?: string | null
          territory?: string | null
        }
        Update: {
          city?: string | null
          commune?: string | null
          id?: string
          province?: string | null
          territory?: string | null
        }
        Relationships: []
      }
      messages: {
        Row: {
          chat_id: string
          created_at: string | null
          file_type: string | null
          file_url: string | null
          id: string
          sender_id: string | null
          text: string | null
        }
        Insert: {
          chat_id: string
          created_at?: string | null
          file_type?: string | null
          file_url?: string | null
          id?: string
          sender_id?: string | null
          text?: string | null
        }
        Update: {
          chat_id?: string
          created_at?: string | null
          file_type?: string | null
          file_url?: string | null
          id?: string
          sender_id?: string | null
          text?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "messages_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      national_identity: {
        Row: {
          created_at: string | null
          document_type: string | null
          expiry_date: string | null
          id: string
          id_number: string
          issuance_date: string | null
          issuance_place: string | null
          photo_recto_url: string | null
          photo_selfie_url: string | null
          photo_verso_url: string | null
          status: string | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          document_type?: string | null
          expiry_date?: string | null
          id?: string
          id_number: string
          issuance_date?: string | null
          issuance_place?: string | null
          photo_recto_url?: string | null
          photo_selfie_url?: string | null
          photo_verso_url?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          document_type?: string | null
          expiry_date?: string | null
          id?: string
          id_number?: string
          issuance_date?: string | null
          issuance_place?: string | null
          photo_recto_url?: string | null
          photo_selfie_url?: string | null
          photo_verso_url?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      notifications: {
        Row: {
          created_at: string | null
          id: string
          message: string | null
          seen: boolean | null
          title: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          message?: string | null
          seen?: boolean | null
          title?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          message?: string | null
          seen?: boolean | null
          title?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      origin: {
        Row: {
          father_name: string | null
          id: string
          mother_name: string | null
          province: string | null
          sector: string | null
          territory: string | null
          user_id: string | null
        }
        Insert: {
          father_name?: string | null
          id?: string
          mother_name?: string | null
          province?: string | null
          sector?: string | null
          territory?: string | null
          user_id?: string | null
        }
        Update: {
          father_name?: string | null
          id?: string
          mother_name?: string | null
          province?: string | null
          sector?: string | null
          territory?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "origin_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          amount: number | null
          created_at: string | null
          id: string
          provider: string | null
          status: string | null
          transaction_id: string
          user_id: string
        }
        Insert: {
          amount?: number | null
          created_at?: string | null
          id?: string
          provider?: string | null
          status?: string | null
          transaction_id: string
          user_id: string
        }
        Update: {
          amount?: number | null
          created_at?: string | null
          id?: string
          provider?: string | null
          status?: string | null
          transaction_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "payments_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      permission_scopes: {
        Row: {
          id: number
          name: string
        }
        Insert: {
          id?: number
          name: string
        }
        Update: {
          id?: number
          name?: string
        }
        Relationships: []
      }
      permissions: {
        Row: {
          id: number
          name: string
        }
        Insert: {
          id?: number
          name: string
        }
        Update: {
          id?: number
          name?: string
        }
        Relationships: []
      }
      profile_access_requests: {
        Row: {
          approved_until: string | null
          created_at: string | null
          id: string
          profile_id: string
          requester_id: string
          status: string | null
        }
        Insert: {
          approved_until?: string | null
          created_at?: string | null
          id?: string
          profile_id: string
          requester_id: string
          status?: string | null
        }
        Update: {
          approved_until?: string | null
          created_at?: string | null
          id?: string
          profile_id?: string
          requester_id?: string
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "profile_access_requests_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          address: string | null
          avatar_url: string | null
          avenue: string | null
          bio: string | null
          bio_professional: string | null
          birth_date: string | null
          birth_place: string | null
          blood_group: string | null
          city: string | null
          commune: string | null
          commune_residence: string | null
          company_name: string | null
          competence: string | null
          contact_phone: string | null
          country_or_origin: string | null
          created_at: string | null
          current_avenue: string | null
          current_city: string | null
          current_commune: string | null
          current_country: string | null
          current_house_number: string | null
          current_neighborhood: string | null
          current_number: string | null
          current_province: string | null
          current_province_id: number | null
          current_residence_country: string | null
          current_territory: string | null
          current_territory_id: number | null
          date_emission_piece: string | null
          date_expiration_piece: string | null
          date_of_birth: string | null
          disability: string | null
          display_name: string | null
          document_type: string | null
          education: string | null
          emergency_contact_name: string | null
          emergency_contact_phone: string | null
          emergency_contact_relation: string | null
          emergency_contacts: Json | null
          experience: string | null
          expiry_date: string | null
          father_name: string | null
          full_name: string | null
          gender: string | null
          groupe_sanguin: string | null
          handicap_physique: boolean | null
          has_physical_disability: boolean | null
          height: string | null
          height_cm: number | null
          id: string
          id_document_expiry_date: string | null
          id_document_issue_date: string | null
          id_document_issue_place: string | null
          id_document_type: string | null
          id_expiry_date: string | null
          id_issue_date: string | null
          id_issue_place: string | null
          id_type: string | null
          is_active: boolean | null
          is_private: boolean | null
          is_verified: boolean | null
          issue_date: string | null
          issue_place: string | null
          job_title: string | null
          languages: string[] | null
          last_diploma: string | null
          last_name: string | null
          lieu_emission_piece: string | null
          location: string | null
          main_missions: string | null
          marital_status: string | null
          mother_name: string | null
          national_id: string | null
          national_id_number: string | null
          nationality: string | null
          numero_id_national: string | null
          numero_maison: string | null
          numero_residence: string | null
          occupation: string | null
          origin_country: string | null
          origin_province: string | null
          origin_province_id: number | null
          origin_sector: string | null
          origin_territory: string | null
          origin_territory_id: number | null
          payment_status: string | null
          pays: string | null
          pays_residence: string | null
          phone_number: string | null
          photo_url: string | null
          physical_handicap: boolean | null
          place_of_birth: string | null
          poids_kg: number | null
          profession: string | null
          province: string | null
          province_origine: string | null
          province_residence: string | null
          quartier: string | null
          res_avenue: string | null
          res_commune: string | null
          res_numero: string | null
          res_pays: string | null
          res_province: string | null
          res_quartier: string | null
          res_territoire: string | null
          res_ville: string | null
          residence_avenue: string | null
          residence_city: string | null
          residence_commune: string | null
          residence_country: string | null
          residence_number: string | null
          residence_province: string | null
          residence_quarter: string | null
          residence_territory: string | null
          role: string | null
          secteur_origine: string | null
          sector: string | null
          skills_summary: string | null
          study_city: string | null
          study_end_year: string | null
          study_start_year: string | null
          subscription_status: string | null
          taille_cm: number | null
          territoire: string | null
          territoire_origine: string | null
          thix_chat: boolean | null
          thix_chat_handle: string | null
          thix_email_phone: string | null
          thix_id: string | null
          thix_uid: string | null
          trial_ends_at: string | null
          trial_started_at: string | null
          type_piece_identite: string | null
          university_name: string | null
          updated_at: string | null
          urgence_lien: string | null
          urgence_nom: string | null
          urgence_tel: string | null
          urgence_telephone: string | null
          verification_level: string | null
          ville: string | null
          ville_residence: string | null
          weight: string | null
          weight_kg: number | null
        }
        Insert: {
          address?: string | null
          avatar_url?: string | null
          avenue?: string | null
          bio?: string | null
          bio_professional?: string | null
          birth_date?: string | null
          birth_place?: string | null
          blood_group?: string | null
          city?: string | null
          commune?: string | null
          commune_residence?: string | null
          company_name?: string | null
          competence?: string | null
          contact_phone?: string | null
          country_or_origin?: string | null
          created_at?: string | null
          current_avenue?: string | null
          current_city?: string | null
          current_commune?: string | null
          current_country?: string | null
          current_house_number?: string | null
          current_neighborhood?: string | null
          current_number?: string | null
          current_province?: string | null
          current_province_id?: number | null
          current_residence_country?: string | null
          current_territory?: string | null
          current_territory_id?: number | null
          date_emission_piece?: string | null
          date_expiration_piece?: string | null
          date_of_birth?: string | null
          disability?: string | null
          display_name?: string | null
          document_type?: string | null
          education?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          emergency_contact_relation?: string | null
          emergency_contacts?: Json | null
          experience?: string | null
          expiry_date?: string | null
          father_name?: string | null
          full_name?: string | null
          gender?: string | null
          groupe_sanguin?: string | null
          handicap_physique?: boolean | null
          has_physical_disability?: boolean | null
          height?: string | null
          height_cm?: number | null
          id?: string
          id_document_expiry_date?: string | null
          id_document_issue_date?: string | null
          id_document_issue_place?: string | null
          id_document_type?: string | null
          id_expiry_date?: string | null
          id_issue_date?: string | null
          id_issue_place?: string | null
          id_type?: string | null
          is_active?: boolean | null
          is_private?: boolean | null
          is_verified?: boolean | null
          issue_date?: string | null
          issue_place?: string | null
          job_title?: string | null
          languages?: string[] | null
          last_diploma?: string | null
          last_name?: string | null
          lieu_emission_piece?: string | null
          location?: string | null
          main_missions?: string | null
          marital_status?: string | null
          mother_name?: string | null
          national_id?: string | null
          national_id_number?: string | null
          nationality?: string | null
          numero_id_national?: string | null
          numero_maison?: string | null
          numero_residence?: string | null
          occupation?: string | null
          origin_country?: string | null
          origin_province?: string | null
          origin_province_id?: number | null
          origin_sector?: string | null
          origin_territory?: string | null
          origin_territory_id?: number | null
          payment_status?: string | null
          pays?: string | null
          pays_residence?: string | null
          phone_number?: string | null
          photo_url?: string | null
          physical_handicap?: boolean | null
          place_of_birth?: string | null
          poids_kg?: number | null
          profession?: string | null
          province?: string | null
          province_origine?: string | null
          province_residence?: string | null
          quartier?: string | null
          res_avenue?: string | null
          res_commune?: string | null
          res_numero?: string | null
          res_pays?: string | null
          res_province?: string | null
          res_quartier?: string | null
          res_territoire?: string | null
          res_ville?: string | null
          residence_avenue?: string | null
          residence_city?: string | null
          residence_commune?: string | null
          residence_country?: string | null
          residence_number?: string | null
          residence_province?: string | null
          residence_quarter?: string | null
          residence_territory?: string | null
          role?: string | null
          secteur_origine?: string | null
          sector?: string | null
          skills_summary?: string | null
          study_city?: string | null
          study_end_year?: string | null
          study_start_year?: string | null
          subscription_status?: string | null
          taille_cm?: number | null
          territoire?: string | null
          territoire_origine?: string | null
          thix_chat?: boolean | null
          thix_chat_handle?: string | null
          thix_email_phone?: string | null
          thix_id?: string | null
          thix_uid?: string | null
          trial_ends_at?: string | null
          trial_started_at?: string | null
          type_piece_identite?: string | null
          university_name?: string | null
          updated_at?: string | null
          urgence_lien?: string | null
          urgence_nom?: string | null
          urgence_tel?: string | null
          urgence_telephone?: string | null
          verification_level?: string | null
          ville?: string | null
          ville_residence?: string | null
          weight?: string | null
          weight_kg?: number | null
        }
        Update: {
          address?: string | null
          avatar_url?: string | null
          avenue?: string | null
          bio?: string | null
          bio_professional?: string | null
          birth_date?: string | null
          birth_place?: string | null
          blood_group?: string | null
          city?: string | null
          commune?: string | null
          commune_residence?: string | null
          company_name?: string | null
          competence?: string | null
          contact_phone?: string | null
          country_or_origin?: string | null
          created_at?: string | null
          current_avenue?: string | null
          current_city?: string | null
          current_commune?: string | null
          current_country?: string | null
          current_house_number?: string | null
          current_neighborhood?: string | null
          current_number?: string | null
          current_province?: string | null
          current_province_id?: number | null
          current_residence_country?: string | null
          current_territory?: string | null
          current_territory_id?: number | null
          date_emission_piece?: string | null
          date_expiration_piece?: string | null
          date_of_birth?: string | null
          disability?: string | null
          display_name?: string | null
          document_type?: string | null
          education?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          emergency_contact_relation?: string | null
          emergency_contacts?: Json | null
          experience?: string | null
          expiry_date?: string | null
          father_name?: string | null
          full_name?: string | null
          gender?: string | null
          groupe_sanguin?: string | null
          handicap_physique?: boolean | null
          has_physical_disability?: boolean | null
          height?: string | null
          height_cm?: number | null
          id?: string
          id_document_expiry_date?: string | null
          id_document_issue_date?: string | null
          id_document_issue_place?: string | null
          id_document_type?: string | null
          id_expiry_date?: string | null
          id_issue_date?: string | null
          id_issue_place?: string | null
          id_type?: string | null
          is_active?: boolean | null
          is_private?: boolean | null
          is_verified?: boolean | null
          issue_date?: string | null
          issue_place?: string | null
          job_title?: string | null
          languages?: string[] | null
          last_diploma?: string | null
          last_name?: string | null
          lieu_emission_piece?: string | null
          location?: string | null
          main_missions?: string | null
          marital_status?: string | null
          mother_name?: string | null
          national_id?: string | null
          national_id_number?: string | null
          nationality?: string | null
          numero_id_national?: string | null
          numero_maison?: string | null
          numero_residence?: string | null
          occupation?: string | null
          origin_country?: string | null
          origin_province?: string | null
          origin_province_id?: number | null
          origin_sector?: string | null
          origin_territory?: string | null
          origin_territory_id?: number | null
          payment_status?: string | null
          pays?: string | null
          pays_residence?: string | null
          phone_number?: string | null
          photo_url?: string | null
          physical_handicap?: boolean | null
          place_of_birth?: string | null
          poids_kg?: number | null
          profession?: string | null
          province?: string | null
          province_origine?: string | null
          province_residence?: string | null
          quartier?: string | null
          res_avenue?: string | null
          res_commune?: string | null
          res_numero?: string | null
          res_pays?: string | null
          res_province?: string | null
          res_quartier?: string | null
          res_territoire?: string | null
          res_ville?: string | null
          residence_avenue?: string | null
          residence_city?: string | null
          residence_commune?: string | null
          residence_country?: string | null
          residence_number?: string | null
          residence_province?: string | null
          residence_quarter?: string | null
          residence_territory?: string | null
          role?: string | null
          secteur_origine?: string | null
          sector?: string | null
          skills_summary?: string | null
          study_city?: string | null
          study_end_year?: string | null
          study_start_year?: string | null
          subscription_status?: string | null
          taille_cm?: number | null
          territoire?: string | null
          territoire_origine?: string | null
          thix_chat?: boolean | null
          thix_chat_handle?: string | null
          thix_email_phone?: string | null
          thix_id?: string | null
          thix_uid?: string | null
          trial_ends_at?: string | null
          trial_started_at?: string | null
          type_piece_identite?: string | null
          university_name?: string | null
          updated_at?: string | null
          urgence_lien?: string | null
          urgence_nom?: string | null
          urgence_tel?: string | null
          urgence_telephone?: string | null
          verification_level?: string | null
          ville?: string | null
          ville_residence?: string | null
          weight?: string | null
          weight_kg?: number | null
        }
        Relationships: []
      }
      provinces: {
        Row: {
          id: string
          name: string
        }
        Insert: {
          id?: string
          name: string
        }
        Update: {
          id?: string
          name?: string
        }
        Relationships: []
      }
      reports: {
        Row: {
          created_at: string | null
          id: string
          reason: string | null
          reported_user_id: string | null
          reporter_id: string
          status: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          reason?: string | null
          reported_user_id?: string | null
          reporter_id: string
          status?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          reason?: string | null
          reported_user_id?: string | null
          reporter_id?: string
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "reports_reported_user_id_fkey"
            columns: ["reported_user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_reporter_id_fkey"
            columns: ["reporter_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      residence: {
        Row: {
          avenue: string | null
          city: string | null
          commune: string | null
          country: string | null
          district: string | null
          id: string
          number: string | null
          province: string | null
          territory: string | null
          user_id: string | null
        }
        Insert: {
          avenue?: string | null
          city?: string | null
          commune?: string | null
          country?: string | null
          district?: string | null
          id?: string
          number?: string | null
          province?: string | null
          territory?: string | null
          user_id?: string | null
        }
        Update: {
          avenue?: string | null
          city?: string | null
          commune?: string | null
          country?: string | null
          district?: string | null
          id?: string
          number?: string | null
          province?: string | null
          territory?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "residence_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          permission_id: number
          role_id: number
          scope_id: number
        }
        Insert: {
          permission_id: number
          role_id: number
          scope_id: number
        }
        Update: {
          permission_id?: number
          role_id?: number
          scope_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_permission_id_fkey"
            columns: ["permission_id"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_permissions_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_permissions_scope_id_fkey"
            columns: ["scope_id"]
            isOneToOne: false
            referencedRelation: "permission_scopes"
            referencedColumns: ["id"]
          },
        ]
      }
      roles: {
        Row: {
          id: number
          name: string
        }
        Insert: {
          id?: number
          name: string
        }
        Update: {
          id?: number
          name?: string
        }
        Relationships: []
      }
      skills: {
        Row: {
          id: string
          is_public: boolean | null
          level: string | null
          skill_name: string | null
          user_id: string | null
        }
        Insert: {
          id?: string
          is_public?: boolean | null
          level?: string | null
          skill_name?: string | null
          user_id?: string | null
        }
        Update: {
          id?: string
          is_public?: boolean | null
          level?: string | null
          skill_name?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "skills_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      sos_alerts: {
        Row: {
          created_at: string | null
          id: string
          location_lat: number | null
          location_long: number | null
          severity_level: number | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          location_lat?: number | null
          location_long?: number | null
          severity_level?: number | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          location_lat?: number | null
          location_long?: number | null
          severity_level?: number | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "sos_alerts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      spatial_ref_sys: {
        Row: {
          auth_name: string | null
          auth_srid: number | null
          proj4text: string | null
          srid: number
          srtext: string | null
        }
        Insert: {
          auth_name?: string | null
          auth_srid?: number | null
          proj4text?: string | null
          srid: number
          srtext?: string | null
        }
        Update: {
          auth_name?: string | null
          auth_srid?: number | null
          proj4text?: string | null
          srid?: number
          srtext?: string | null
        }
        Relationships: []
      }
      statuses: {
        Row: {
          background_color: string | null
          caption: string | null
          content_url: string | null
          created_at: string | null
          expires_at: string | null
          id: string
          type: string
          user_id: string
        }
        Insert: {
          background_color?: string | null
          caption?: string | null
          content_url?: string | null
          created_at?: string | null
          expires_at?: string | null
          id?: string
          type: string
          user_id: string
        }
        Update: {
          background_color?: string | null
          caption?: string | null
          content_url?: string | null
          created_at?: string | null
          expires_at?: string | null
          id?: string
          type?: string
          user_id?: string
        }
        Relationships: []
      }
      territoires: {
        Row: {
          id: string
          name: string
          province_id: string | null
        }
        Insert: {
          id?: string
          name: string
          province_id?: string | null
        }
        Update: {
          id?: string
          name?: string
          province_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "territoires_province_id_fkey"
            columns: ["province_id"]
            isOneToOne: false
            referencedRelation: "provinces"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_admin_access_requests: {
        Row: {
          created_at: string
          decided_at: string | null
          decided_by: string | null
          decided_role: string | null
          desired_role: string
          id: string
          message: string | null
          requester_id: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          decided_role?: string | null
          desired_role?: string
          id?: string
          message?: string | null
          requester_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          decided_role?: string | null
          desired_role?: string
          id?: string
          message?: string | null
          requester_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      thix_admin_audit_logs: {
        Row: {
          action: string
          actor_role: string | null
          actor_user_id: string | null
          created_at: string
          entity_id: string | null
          entity_type: string
          id: number
          metadata: Json
        }
        Insert: {
          action: string
          actor_role?: string | null
          actor_user_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type: string
          id?: number
          metadata?: Json
        }
        Update: {
          action?: string
          actor_role?: string | null
          actor_user_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type?: string
          id?: number
          metadata?: Json
        }
        Relationships: []
      }
      thix_admin_memberships: {
        Row: {
          assigned_at: string | null
          email: string | null
          group_name: string | null
          role: string | null
          status: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          assigned_at?: string | null
          email?: string | null
          group_name?: string | null
          role?: string | null
          status?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          assigned_at?: string | null
          email?: string | null
          group_name?: string | null
          role?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      thix_call_signals: {
        Row: {
          call_id: string
          created_at: string
          from_user_id: string
          id: string
          payload: Json
          to_user_id: string
          type: string
        }
        Insert: {
          call_id: string
          created_at?: string
          from_user_id: string
          id?: string
          payload?: Json
          to_user_id: string
          type: string
        }
        Update: {
          call_id?: string
          created_at?: string
          from_user_id?: string
          id?: string
          payload?: Json
          to_user_id?: string
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_call_signals_call_id_fkey"
            columns: ["call_id"]
            isOneToOne: false
            referencedRelation: "call_history"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_chat_chats: {
        Row: {
          created_at: string | null
          direct_key: string | null
          id: string
          is_read: boolean | null
          message_content: string
          participants: Json | null
          receiver_id: string | null
          sender_id: string | null
          title: string | null
          type: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          direct_key?: string | null
          id?: string
          is_read?: boolean | null
          message_content: string
          participants?: Json | null
          receiver_id?: string | null
          sender_id?: string | null
          title?: string | null
          type?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          direct_key?: string | null
          id?: string
          is_read?: boolean | null
          message_content?: string
          participants?: Json | null
          receiver_id?: string | null
          sender_id?: string | null
          title?: string | null
          type?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      thix_companies: {
        Row: {
          about: string | null
          banner_url: string | null
          city: string | null
          country: string | null
          created_at: string
          id: string
          is_verified: boolean
          logo_url: string | null
          name: string
          updated_at: string
        }
        Insert: {
          about?: string | null
          banner_url?: string | null
          city?: string | null
          country?: string | null
          created_at?: string
          id?: string
          is_verified?: boolean
          logo_url?: string | null
          name: string
          updated_at?: string
        }
        Update: {
          about?: string | null
          banner_url?: string | null
          city?: string | null
          country?: string | null
          created_at?: string
          id?: string
          is_verified?: boolean
          logo_url?: string | null
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      thix_emergency_admins: {
        Row: {
          created_at: string | null
          id: string
          name: string | null
          phone_number: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          name?: string | null
          phone_number?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          name?: string | null
          phone_number?: string | null
        }
        Relationships: []
      }
      thix_emergency_alerts: {
        Row: {
          audio_path: string | null
          created_at: string | null
          description: string | null
          id: string
          is_critical: boolean | null
          last_accuracy_m: number | null
          last_lat: number | null
          last_lng: number | null
          last_location_at: string | null
          latitude: number | null
          longitude: number | null
          message: string | null
          metadata: Json
          severity: string | null
          silent_mode: boolean | null
          status: string | null
          title: string | null
          type: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          audio_path?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          is_critical?: boolean | null
          last_accuracy_m?: number | null
          last_lat?: number | null
          last_lng?: number | null
          last_location_at?: string | null
          latitude?: number | null
          longitude?: number | null
          message?: string | null
          metadata?: Json
          severity?: string | null
          silent_mode?: boolean | null
          status?: string | null
          title?: string | null
          type?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          audio_path?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          is_critical?: boolean | null
          last_accuracy_m?: number | null
          last_lat?: number | null
          last_lng?: number | null
          last_location_at?: string | null
          latitude?: number | null
          longitude?: number | null
          message?: string | null
          metadata?: Json
          severity?: string | null
          silent_mode?: boolean | null
          status?: string | null
          title?: string | null
          type?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: []
      }
      thix_emergency_audit_logs: {
        Row: {
          action: string
          actor_user_id: string | null
          created_at: string
          entity_id: string | null
          entity_type: string
          id: number
          metadata: Json
        }
        Insert: {
          action: string
          actor_user_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type: string
          id?: number
          metadata?: Json
        }
        Update: {
          action?: string
          actor_user_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type?: string
          id?: number
          metadata?: Json
        }
        Relationships: []
      }
      thix_emergency_evidence: {
        Row: {
          alert_id: string
          created_at: string
          file_name: string | null
          file_size_bytes: number | null
          id: string
          kind: string
          mime_type: string | null
          storage_path: string
        }
        Insert: {
          alert_id: string
          created_at?: string
          file_name?: string | null
          file_size_bytes?: number | null
          id?: string
          kind: string
          mime_type?: string | null
          storage_path: string
        }
        Update: {
          alert_id?: string
          created_at?: string
          file_name?: string | null
          file_size_bytes?: number | null
          id?: string
          kind?: string
          mime_type?: string | null
          storage_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_emergency_evidence_alert_id_fkey"
            columns: ["alert_id"]
            isOneToOne: false
            referencedRelation: "thix_emergency_alerts"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_emergency_locations: {
        Row: {
          accuracy_m: number | null
          alert_id: string
          captured_at: string
          created_at: string
          heading_deg: number | null
          id: number
          lat: number
          lng: number
          speed_mps: number | null
        }
        Insert: {
          accuracy_m?: number | null
          alert_id: string
          captured_at?: string
          created_at?: string
          heading_deg?: number | null
          id?: number
          lat: number
          lng: number
          speed_mps?: number | null
        }
        Update: {
          accuracy_m?: number | null
          alert_id?: string
          captured_at?: string
          created_at?: string
          heading_deg?: number | null
          id?: number
          lat?: number
          lng?: number
          speed_mps?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "thix_emergency_locations_alert_id_fkey"
            columns: ["alert_id"]
            isOneToOne: false
            referencedRelation: "thix_emergency_alerts"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_event_registrations: {
        Row: {
          created_at: string
          event_id: string
          id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          event_id: string
          id?: string
          user_id: string
        }
        Update: {
          created_at?: string
          event_id?: string
          id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_event_registrations_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "thix_events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thix_event_registrations_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "thix_events_status"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_events: {
        Row: {
          agenda: Json
          category: string | null
          cover_image_bucket: string | null
          cover_image_path: string | null
          created_at: string
          description: string | null
          event_type: string
          highlights: Json
          id: string
          is_featured: boolean
          is_free: boolean
          max_participants: number
          meeting_link: string | null
          organizer: string
          place: string
          price: number | null
          quick_hook: string | null
          speakers: Json
          sponsors: Json
          starts_at: string
          status: string
          title: string
          updated_at: string
          virtual_link: string | null
        }
        Insert: {
          agenda?: Json
          category?: string | null
          cover_image_bucket?: string | null
          cover_image_path?: string | null
          created_at?: string
          description?: string | null
          event_type?: string
          highlights?: Json
          id?: string
          is_featured?: boolean
          is_free?: boolean
          max_participants?: number
          meeting_link?: string | null
          organizer?: string
          place: string
          price?: number | null
          quick_hook?: string | null
          speakers?: Json
          sponsors?: Json
          starts_at: string
          status?: string
          title: string
          updated_at?: string
          virtual_link?: string | null
        }
        Update: {
          agenda?: Json
          category?: string | null
          cover_image_bucket?: string | null
          cover_image_path?: string | null
          created_at?: string
          description?: string | null
          event_type?: string
          highlights?: Json
          id?: string
          is_featured?: boolean
          is_free?: boolean
          max_participants?: number
          meeting_link?: string | null
          organizer?: string
          place?: string
          price?: number | null
          quick_hook?: string | null
          speakers?: Json
          sponsors?: Json
          starts_at?: string
          status?: string
          title?: string
          updated_at?: string
          virtual_link?: string | null
        }
        Relationships: []
      }
      thix_info_news: {
        Row: {
          author_id: string | null
          body: string | null
          category: string | null
          content: string | null
          created_at: string | null
          description: string | null
          featured: boolean | null
          id: string
          image_url: string | null
          is_featured: boolean | null
          photo_url: string | null
          severity: string | null
          source: string | null
          subtitle: string | null
          summary: string | null
          thumbnail: string | null
          title: string
        }
        Insert: {
          author_id?: string | null
          body?: string | null
          category?: string | null
          content?: string | null
          created_at?: string | null
          description?: string | null
          featured?: boolean | null
          id?: string
          image_url?: string | null
          is_featured?: boolean | null
          photo_url?: string | null
          severity?: string | null
          source?: string | null
          subtitle?: string | null
          summary?: string | null
          thumbnail?: string | null
          title: string
        }
        Update: {
          author_id?: string | null
          body?: string | null
          category?: string | null
          content?: string | null
          created_at?: string | null
          description?: string | null
          featured?: boolean | null
          id?: string
          image_url?: string | null
          is_featured?: boolean | null
          photo_url?: string | null
          severity?: string | null
          source?: string | null
          subtitle?: string | null
          summary?: string | null
          thumbnail?: string | null
          title?: string
        }
        Relationships: []
      }
      thix_job_applications: {
        Row: {
          applicant_id: string | null
          cover_letter: string | null
          created_at: string | null
          id: string
          job_id: string | null
          recruiter_user_id: string | null
          resume_url: string | null
          status: string | null
          updated_at: string
        }
        Insert: {
          applicant_id?: string | null
          cover_letter?: string | null
          created_at?: string | null
          id?: string
          job_id?: string | null
          recruiter_user_id?: string | null
          resume_url?: string | null
          status?: string | null
          updated_at?: string
        }
        Update: {
          applicant_id?: string | null
          cover_letter?: string | null
          created_at?: string | null
          id?: string
          job_id?: string | null
          recruiter_user_id?: string | null
          resume_url?: string | null
          status?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_job_applications_job_id_fkey"
            columns: ["job_id"]
            isOneToOne: false
            referencedRelation: "thix_job_offers"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_job_interviews: {
        Row: {
          applicant_user_id: string
          application_id: string
          created_at: string
          id: string
          job_id: string
          meeting_url: string | null
          mode: string
          recruiter_user_id: string
          scheduled_at: string
          status: string
          updated_at: string
        }
        Insert: {
          applicant_user_id: string
          application_id: string
          created_at?: string
          id?: string
          job_id: string
          meeting_url?: string | null
          mode?: string
          recruiter_user_id: string
          scheduled_at: string
          status?: string
          updated_at?: string
        }
        Update: {
          applicant_user_id?: string
          application_id?: string
          created_at?: string
          id?: string
          job_id?: string
          meeting_url?: string | null
          mode?: string
          recruiter_user_id?: string
          scheduled_at?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      thix_job_messages: {
        Row: {
          application_id: string | null
          body: string
          created_at: string
          id: string
          job_id: string
          receiver_user_id: string
          sender_user_id: string
          updated_at: string
        }
        Insert: {
          application_id?: string | null
          body: string
          created_at?: string
          id?: string
          job_id: string
          receiver_user_id: string
          sender_user_id: string
          updated_at?: string
        }
        Update: {
          application_id?: string | null
          body?: string
          created_at?: string
          id?: string
          job_id?: string
          receiver_user_id?: string
          sender_user_id?: string
          updated_at?: string
        }
        Relationships: []
      }
      thix_job_offers: {
        Row: {
          applicants_count: number
          benefits: string[] | null
          category: string | null
          company: string | null
          company_id: string | null
          company_logo_url: string | null
          created_at: string | null
          created_by: string | null
          deadline: string | null
          description: string | null
          experience_level: string | null
          id: string
          image_url: string | null
          industry: string | null
          is_featured: boolean
          is_verified_employer: boolean
          location: string | null
          posted_by: string | null
          recruiter_user_id: string | null
          reference_number: string | null
          requirements: string[] | null
          responsibilities: string[] | null
          salary_currency: string | null
          salary_max: number | null
          salary_min: number | null
          salary_range: string | null
          skills: string[] | null
          status: string | null
          tags: string[] | null
          title: string
          updated_at: string
          work_mode: string | null
        }
        Insert: {
          applicants_count?: number
          benefits?: string[] | null
          category?: string | null
          company?: string | null
          company_id?: string | null
          company_logo_url?: string | null
          created_at?: string | null
          created_by?: string | null
          deadline?: string | null
          description?: string | null
          experience_level?: string | null
          id?: string
          image_url?: string | null
          industry?: string | null
          is_featured?: boolean
          is_verified_employer?: boolean
          location?: string | null
          posted_by?: string | null
          recruiter_user_id?: string | null
          reference_number?: string | null
          requirements?: string[] | null
          responsibilities?: string[] | null
          salary_currency?: string | null
          salary_max?: number | null
          salary_min?: number | null
          salary_range?: string | null
          skills?: string[] | null
          status?: string | null
          tags?: string[] | null
          title: string
          updated_at?: string
          work_mode?: string | null
        }
        Update: {
          applicants_count?: number
          benefits?: string[] | null
          category?: string | null
          company?: string | null
          company_id?: string | null
          company_logo_url?: string | null
          created_at?: string | null
          created_by?: string | null
          deadline?: string | null
          description?: string | null
          experience_level?: string | null
          id?: string
          image_url?: string | null
          industry?: string | null
          is_featured?: boolean
          is_verified_employer?: boolean
          location?: string | null
          posted_by?: string | null
          recruiter_user_id?: string | null
          reference_number?: string | null
          requirements?: string[] | null
          responsibilities?: string[] | null
          salary_currency?: string | null
          salary_max?: number | null
          salary_min?: number | null
          salary_range?: string | null
          skills?: string[] | null
          status?: string | null
          tags?: string[] | null
          title?: string
          updated_at?: string
          work_mode?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "thix_job_offers_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "thix_companies"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_job_saved: {
        Row: {
          created_at: string
          job_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          job_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          job_id?: string
          user_id?: string
        }
        Relationships: []
      }
      thix_notifications: {
        Row: {
          body: string
          created_at: string
          data: Json
          id: string
          read: boolean
          title: string
          type: string
          user_id: string | null
        }
        Insert: {
          body?: string
          created_at?: string
          data?: Json
          id?: string
          read?: boolean
          title: string
          type?: string
          user_id?: string | null
        }
        Update: {
          body?: string
          created_at?: string
          data?: Json
          id?: string
          read?: boolean
          title?: string
          type?: string
          user_id?: string | null
        }
        Relationships: []
      }
      thix_official_courses: {
        Row: {
          cover_image_url: string | null
          created_at: string | null
          created_by: string | null
          description: string | null
          id: string
          instructor_name: string | null
          price: number | null
          title: string
        }
        Insert: {
          cover_image_url?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          id?: string
          instructor_name?: string | null
          price?: number | null
          title: string
        }
        Update: {
          cover_image_url?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          id?: string
          instructor_name?: string | null
          price?: number | null
          title?: string
        }
        Relationships: []
      }
      thix_opportunities: {
        Row: {
          apply_url: string | null
          category: string | null
          created_at: string
          created_by: string | null
          deadline: string | null
          deadline_label: string | null
          description: string | null
          eligibility: string[]
          id: string
          image_url: string | null
          location: string | null
          organizer: string | null
          reward_label: string | null
          status: string
          title: string
          updated_at: string
        }
        Insert: {
          apply_url?: string | null
          category?: string | null
          created_at?: string
          created_by?: string | null
          deadline?: string | null
          deadline_label?: string | null
          description?: string | null
          eligibility?: string[]
          id?: string
          image_url?: string | null
          location?: string | null
          organizer?: string | null
          reward_label?: string | null
          status?: string
          title: string
          updated_at?: string
        }
        Update: {
          apply_url?: string | null
          category?: string | null
          created_at?: string
          created_by?: string | null
          deadline?: string | null
          deadline_label?: string | null
          description?: string | null
          eligibility?: string[]
          id?: string
          image_url?: string | null
          location?: string | null
          organizer?: string | null
          reward_label?: string | null
          status?: string
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      thix_presence: {
        Row: {
          is_online: boolean
          last_seen_at: string
          updated_at: string
          user_id: string
        }
        Insert: {
          is_online?: boolean
          last_seen_at?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          is_online?: boolean
          last_seen_at?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      thix_public_profiles: {
        Row: {
          account_status: string | null
          account_type: string | null
          avatar_url: string | null
          created_at: string | null
          display_name: string | null
          full_name: string | null
          id: string
          identity_preview_url: string | null
          identity_verified_at: string | null
          is_suspended: boolean
          is_verified: boolean | null
          last_update: string | null
          suspended_at: string | null
          suspended_by: string | null
          suspended_reason: string | null
          trust_level: string | null
          user_id: string | null
        }
        Insert: {
          account_status?: string | null
          account_type?: string | null
          avatar_url?: string | null
          created_at?: string | null
          display_name?: string | null
          full_name?: string | null
          id?: string
          identity_preview_url?: string | null
          identity_verified_at?: string | null
          is_suspended?: boolean
          is_verified?: boolean | null
          last_update?: string | null
          suspended_at?: string | null
          suspended_by?: string | null
          suspended_reason?: string | null
          trust_level?: string | null
          user_id?: string | null
        }
        Update: {
          account_status?: string | null
          account_type?: string | null
          avatar_url?: string | null
          created_at?: string | null
          display_name?: string | null
          full_name?: string | null
          id?: string
          identity_preview_url?: string | null
          identity_verified_at?: string | null
          is_suspended?: boolean
          is_verified?: boolean | null
          last_update?: string | null
          suspended_at?: string | null
          suspended_by?: string | null
          suspended_reason?: string | null
          trust_level?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      thix_push_tokens: {
        Row: {
          active: boolean
          created_at: string
          id: string
          last_seen_at: string | null
          platform: string
          token: string
          updated_at: string
          user_id: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          id?: string
          last_seen_at?: string | null
          platform: string
          token: string
          updated_at?: string
          user_id: string
        }
        Update: {
          active?: boolean
          created_at?: string
          id?: string
          last_seen_at?: string | null
          platform?: string
          token?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      thix_safety_ads: {
        Row: {
          content: string | null
          created_at: string | null
          id: string
          image_url: string | null
          title: string | null
        }
        Insert: {
          content?: string | null
          created_at?: string | null
          id?: string
          image_url?: string | null
          title?: string | null
        }
        Update: {
          content?: string | null
          created_at?: string | null
          id?: string
          image_url?: string | null
          title?: string | null
        }
        Relationships: []
      }
      thix_section_seen_state: {
        Row: {
          created_at: string
          seen_events_at: string | null
          seen_formations_at: string | null
          seen_info_at: string | null
          seen_jobs_at: string | null
          seen_messages_at: string | null
          seen_opportunities_at: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          seen_events_at?: string | null
          seen_formations_at?: string | null
          seen_info_at?: string | null
          seen_jobs_at?: string | null
          seen_messages_at?: string | null
          seen_opportunities_at?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          seen_events_at?: string | null
          seen_formations_at?: string | null
          seen_info_at?: string | null
          seen_jobs_at?: string | null
          seen_messages_at?: string | null
          seen_opportunities_at?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      thix_security_events: {
        Row: {
          created_at: string | null
          description: string | null
          event_type: string | null
          id: string
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          event_type?: string | null
          id?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          event_type?: string | null
          id?: string
          user_id?: string | null
        }
        Relationships: []
      }
      thix_status_updates: {
        Row: {
          content: string | null
          created_at: string | null
          id: string
        }
        Insert: {
          content?: string | null
          created_at?: string | null
          id?: string
        }
        Update: {
          content?: string | null
          created_at?: string | null
          id?: string
        }
        Relationships: []
      }
      thix_training_certificates: {
        Row: {
          created_at: string
          id: string
          issued_at: string
          revoked_at: string | null
          status: string
          training_id: string
          updated_at: string
          user_id: string
          verification_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          issued_at?: string
          revoked_at?: string | null
          status?: string
          training_id: string
          updated_at?: string
          user_id: string
          verification_id: string
        }
        Update: {
          created_at?: string
          id?: string
          issued_at?: string
          revoked_at?: string | null
          status?: string
          training_id?: string
          updated_at?: string
          user_id?: string
          verification_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_training_certificates_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thix_training_certificates_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings_status"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_training_enrollments: {
        Row: {
          completed_at: string | null
          created_at: string
          id: string
          last_activity_at: string | null
          learning_minutes: number
          progress_percent: number
          status: string
          training_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string
          id?: string
          last_activity_at?: string | null
          learning_minutes?: number
          progress_percent?: number
          status?: string
          training_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string
          id?: string
          last_activity_at?: string | null
          learning_minutes?: number
          progress_percent?: number
          status?: string
          training_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_training_enrollments_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thix_training_enrollments_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings_status"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_training_lessons: {
        Row: {
          created_at: string
          duration_minutes: number | null
          id: string
          is_preview: boolean
          lesson_index: number
          module_index: number
          resources: Json | null
          title: string
          training_id: string
          type: string
          updated_at: string
          video_url: string | null
        }
        Insert: {
          created_at?: string
          duration_minutes?: number | null
          id?: string
          is_preview?: boolean
          lesson_index?: number
          module_index?: number
          resources?: Json | null
          title: string
          training_id: string
          type?: string
          updated_at?: string
          video_url?: string | null
        }
        Update: {
          created_at?: string
          duration_minutes?: number | null
          id?: string
          is_preview?: boolean
          lesson_index?: number
          module_index?: number
          resources?: Json | null
          title?: string
          training_id?: string
          type?: string
          updated_at?: string
          video_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "thix_training_lessons_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thix_training_lessons_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings_status"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_training_reviews: {
        Row: {
          comment: string | null
          created_at: string
          id: string
          rating: number
          training_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          comment?: string | null
          created_at?: string
          id?: string
          rating: number
          training_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          comment?: string | null
          created_at?: string
          id?: string
          rating?: number
          training_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_training_reviews_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thix_training_reviews_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings_status"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_trainings: {
        Row: {
          category: string
          certification_included: boolean
          cover_image_bucket: string | null
          cover_image_path: string | null
          created_at: string
          currency: string
          delivery_mode: string
          description: string | null
          duration_minutes: number | null
          id: string
          institution_logo_url: string | null
          institution_name: string | null
          instructor_avatar_url: string | null
          instructor_name: string | null
          instructor_title: string | null
          is_featured: boolean
          is_free: boolean
          is_published: boolean
          language: string
          level: string
          price_amount: number | null
          requirements: string | null
          skills: string[]
          start_date: string | null
          tagline: string | null
          title: string
          updated_at: string
        }
        Insert: {
          category?: string
          certification_included?: boolean
          cover_image_bucket?: string | null
          cover_image_path?: string | null
          created_at?: string
          currency?: string
          delivery_mode?: string
          description?: string | null
          duration_minutes?: number | null
          id?: string
          institution_logo_url?: string | null
          institution_name?: string | null
          instructor_avatar_url?: string | null
          instructor_name?: string | null
          instructor_title?: string | null
          is_featured?: boolean
          is_free?: boolean
          is_published?: boolean
          language?: string
          level?: string
          price_amount?: number | null
          requirements?: string | null
          skills?: string[]
          start_date?: string | null
          tagline?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          category?: string
          certification_included?: boolean
          cover_image_bucket?: string | null
          cover_image_path?: string | null
          created_at?: string
          currency?: string
          delivery_mode?: string
          description?: string | null
          duration_minutes?: number | null
          id?: string
          institution_logo_url?: string | null
          institution_name?: string | null
          instructor_avatar_url?: string | null
          instructor_name?: string | null
          instructor_title?: string | null
          is_featured?: boolean
          is_free?: boolean
          is_published?: boolean
          language?: string
          level?: string
          price_amount?: number | null
          requirements?: string | null
          skills?: string[]
          start_date?: string | null
          tagline?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      trusted_contacts: {
        Row: {
          contact_name: string | null
          created_at: string | null
          id: number
          phone: string | null
          user_id: string | null
        }
        Insert: {
          contact_name?: string | null
          created_at?: string | null
          id?: number
          phone?: string | null
          user_id?: string | null
        }
        Update: {
          contact_name?: string | null
          created_at?: string | null
          id?: number
          phone?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      user_education_records: {
        Row: {
          certificate_file_name: string | null
          certificate_path: string | null
          certified_by_thix: boolean | null
          created_at: string | null
          degree_title: string | null
          end_date: string | null
          field_of_study: string | null
          id: string
          school_name: string | null
          start_date: string | null
          user_id: string | null
          verification_status: string | null
          verified_at: string | null
        }
        Insert: {
          certificate_file_name?: string | null
          certificate_path?: string | null
          certified_by_thix?: boolean | null
          created_at?: string | null
          degree_title?: string | null
          end_date?: string | null
          field_of_study?: string | null
          id?: string
          school_name?: string | null
          start_date?: string | null
          user_id?: string | null
          verification_status?: string | null
          verified_at?: string | null
        }
        Update: {
          certificate_file_name?: string | null
          certificate_path?: string | null
          certified_by_thix?: boolean | null
          created_at?: string | null
          degree_title?: string | null
          end_date?: string | null
          field_of_study?: string | null
          id?: string
          school_name?: string | null
          start_date?: string | null
          user_id?: string | null
          verification_status?: string | null
          verified_at?: string | null
        }
        Relationships: []
      }
      user_educations: {
        Row: {
          certificate_url: string | null
          created_at: string | null
          duration: string | null
          end_date: string | null
          id: string
          organized_by: string | null
          skills: string[] | null
          start_date: string | null
          training_name: string | null
          user_id: string | null
        }
        Insert: {
          certificate_url?: string | null
          created_at?: string | null
          duration?: string | null
          end_date?: string | null
          id?: string
          organized_by?: string | null
          skills?: string[] | null
          start_date?: string | null
          training_name?: string | null
          user_id?: string | null
        }
        Update: {
          certificate_url?: string | null
          created_at?: string | null
          duration?: string | null
          end_date?: string | null
          id?: string
          organized_by?: string | null
          skills?: string[] | null
          start_date?: string | null
          training_name?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_educations_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_identity_details: {
        Row: {
          created_at: string | null
          document_type: string | null
          expiry_date: string | null
          id: string
          id_number: string | null
          issue_date: string | null
          issue_place: string | null
          recto_url: string | null
          selfie_url: string | null
          user_id: string | null
          verification_status: string | null
          verso_url: string | null
        }
        Insert: {
          created_at?: string | null
          document_type?: string | null
          expiry_date?: string | null
          id?: string
          id_number?: string | null
          issue_date?: string | null
          issue_place?: string | null
          recto_url?: string | null
          selfie_url?: string | null
          user_id?: string | null
          verification_status?: string | null
          verso_url?: string | null
        }
        Update: {
          created_at?: string | null
          document_type?: string | null
          expiry_date?: string | null
          id?: string
          id_number?: string | null
          issue_date?: string | null
          issue_place?: string | null
          recto_url?: string | null
          selfie_url?: string | null
          user_id?: string | null
          verification_status?: string | null
          verso_url?: string | null
        }
        Relationships: []
      }
      user_languages: {
        Row: {
          created_at: string | null
          id: string
          niveau: string | null
          nom_langue: string
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          niveau?: string | null
          nom_langue: string
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          niveau?: string | null
          nom_langue?: string
          user_id?: string | null
        }
        Relationships: []
      }
      user_push_tokens: {
        Row: {
          created_at: string
          device_info: Json | null
          id: string
          token: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          device_info?: Json | null
          id?: string
          token: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          device_info?: Json | null
          id?: string
          token?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_push_tokens_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          role_id: number
          user_id: string
        }
        Insert: {
          role_id: number
          user_id: string
        }
        Update: {
          role_id?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_roles_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_school_history: {
        Row: {
          created_at: string | null
          degree_name: string | null
          diploma_url: string | null
          end_date: string | null
          id: string
          school_name: string | null
          start_date: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          degree_name?: string | null
          diploma_url?: string | null
          end_date?: string | null
          id?: string
          school_name?: string | null
          start_date?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          degree_name?: string | null
          diploma_url?: string | null
          end_date?: string | null
          id?: string
          school_name?: string | null
          start_date?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_school_history_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_status: {
        Row: {
          caption: string | null
          content_url: string | null
          created_at: string | null
          expires_at: string | null
          id: string
          user_id: string | null
        }
        Insert: {
          caption?: string | null
          content_url?: string | null
          created_at?: string | null
          expires_at?: string | null
          id?: string
          user_id?: string | null
        }
        Update: {
          caption?: string | null
          content_url?: string | null
          created_at?: string | null
          expires_at?: string | null
          id?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_status_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_work_experience: {
        Row: {
          company_name: string | null
          created_at: string | null
          end_date: string | null
          id: string
          job_title: string | null
          reference_letter_url: string | null
          start_date: string | null
          user_id: string | null
        }
        Insert: {
          company_name?: string | null
          created_at?: string | null
          end_date?: string | null
          id?: string
          job_title?: string | null
          reference_letter_url?: string | null
          start_date?: string | null
          user_id?: string | null
        }
        Update: {
          company_name?: string | null
          created_at?: string | null
          end_date?: string | null
          id?: string
          job_title?: string | null
          reference_letter_url?: string | null
          start_date?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_work_experience_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      users: {
        Row: {
          auth_user_id: string | null
          bio: string | null
          created_at: string | null
          email: string
          full_name: string | null
          id: string
          is_verified: boolean | null
          last_login: string | null
          phone: string | null
          profile_image: string | null
          role: number | null
          thix_id: string | null
          thix_uid: string | null
          trust_score: number | null
          two_fa_enabled: boolean | null
          updated_at: string | null
          verified: boolean | null
        }
        Insert: {
          auth_user_id?: string | null
          bio?: string | null
          created_at?: string | null
          email?: string
          full_name?: string | null
          id?: string
          is_verified?: boolean | null
          last_login?: string | null
          phone?: string | null
          profile_image?: string | null
          role?: number | null
          thix_id?: string | null
          thix_uid?: string | null
          trust_score?: number | null
          two_fa_enabled?: boolean | null
          updated_at?: string | null
          verified?: boolean | null
        }
        Update: {
          auth_user_id?: string | null
          bio?: string | null
          created_at?: string | null
          email?: string
          full_name?: string | null
          id?: string
          is_verified?: boolean | null
          last_login?: string | null
          phone?: string | null
          profile_image?: string | null
          role?: number | null
          thix_id?: string | null
          thix_uid?: string | null
          trust_score?: number | null
          two_fa_enabled?: boolean | null
          updated_at?: string | null
          verified?: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_users_role"
            columns: ["role"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      verification_requests: {
        Row: {
          created_at: string | null
          document_type: string | null
          document_url: string
          id: string
          rejection_reason: string | null
          reviewer_id: string | null
          status: string | null
          user_id: string | null
          verified_at: string | null
        }
        Insert: {
          created_at?: string | null
          document_type?: string | null
          document_url: string
          id?: string
          rejection_reason?: string | null
          reviewer_id?: string | null
          status?: string | null
          user_id?: string | null
          verified_at?: string | null
        }
        Update: {
          created_at?: string | null
          document_type?: string | null
          document_url?: string
          id?: string
          rejection_reason?: string | null
          reviewer_id?: string | null
          status?: string | null
          user_id?: string | null
          verified_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "verification_requests_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      villes: {
        Row: {
          id: string
          name: string
          province_id: string | null
        }
        Insert: {
          id?: string
          name: string
          province_id?: string | null
        }
        Update: {
          id?: string
          name?: string
          province_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "villes_province_id_fkey"
            columns: ["province_id"]
            isOneToOne: false
            referencedRelation: "provinces"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      geography_columns: {
        Row: {
          coord_dimension: number | null
          f_geography_column: unknown
          f_table_catalog: unknown
          f_table_name: unknown
          f_table_schema: unknown
          srid: number | null
          type: string | null
        }
        Relationships: []
      }
      geometry_columns: {
        Row: {
          coord_dimension: number | null
          f_geometry_column: unknown
          f_table_catalog: string | null
          f_table_name: unknown
          f_table_schema: unknown
          srid: number | null
          type: string | null
        }
        Insert: {
          coord_dimension?: number | null
          f_geometry_column?: unknown
          f_table_catalog?: string | null
          f_table_name?: unknown
          f_table_schema?: unknown
          srid?: number | null
          type?: string | null
        }
        Update: {
          coord_dimension?: number | null
          f_geometry_column?: unknown
          f_table_catalog?: string | null
          f_table_name?: unknown
          f_table_schema?: unknown
          srid?: number | null
          type?: string | null
        }
        Relationships: []
      }
      thix_events_status: {
        Row: {
          availability_status: string | null
          category: string | null
          cover_image_bucket: string | null
          cover_image_path: string | null
          created_at: string | null
          event_type: string | null
          id: string | null
          is_featured: boolean | null
          is_free: boolean | null
          max_participants: number | null
          meeting_link: string | null
          organizer: string | null
          place: string | null
          places_remaining: number | null
          price: number | null
          quick_hook: string | null
          registrations_count: number | null
          starts_at: string | null
          status: string | null
          title: string | null
          updated_at: string | null
          virtual_link: string | null
        }
        Relationships: []
      }
      thix_trainings_status: {
        Row: {
          category: string | null
          certification_included: boolean | null
          completion_rate: number | null
          cover_image_bucket: string | null
          cover_image_path: string | null
          created_at: string | null
          currency: string | null
          delivery_mode: string | null
          description: string | null
          duration_minutes: number | null
          id: string | null
          institution_logo_url: string | null
          institution_name: string | null
          instructor_avatar_url: string | null
          instructor_name: string | null
          instructor_title: string | null
          is_featured: boolean | null
          is_free: boolean | null
          is_published: boolean | null
          language: string | null
          level: string | null
          price_amount: number | null
          rating: number | null
          requirements: string | null
          reviews_count: number | null
          skills: string[] | null
          start_date: string | null
          students_count: number | null
          tagline: string | null
          title: string | null
          updated_at: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      _postgis_deprecate: {
        Args: { newname: string; oldname: string; version: string }
        Returns: undefined
      }
      _postgis_index_extent: {
        Args: { col: string; tbl: unknown }
        Returns: unknown
      }
      _postgis_pgsql_version: { Args: never; Returns: string }
      _postgis_scripts_pgsql_version: { Args: never; Returns: string }
      _postgis_selectivity: {
        Args: { att_name: string; geom: unknown; mode?: string; tbl: unknown }
        Returns: number
      }
      _postgis_stats: {
        Args: { ""?: string; att_name: string; tbl: unknown }
        Returns: string
      }
      _st_3dintersects: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_contains: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_containsproperly: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_coveredby:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      _st_covers:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      _st_crosses: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_dwithin: {
        Args: {
          geog1: unknown
          geog2: unknown
          tolerance: number
          use_spheroid?: boolean
        }
        Returns: boolean
      }
      _st_equals: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      _st_intersects: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_linecrossingdirection: {
        Args: { line1: unknown; line2: unknown }
        Returns: number
      }
      _st_longestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      _st_maxdistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      _st_orderingequals: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_overlaps: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_sortablehash: { Args: { geom: unknown }; Returns: number }
      _st_touches: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_voronoi: {
        Args: {
          clip?: unknown
          g1: unknown
          return_polygons?: boolean
          tolerance?: number
        }
        Returns: unknown
      }
      _st_within: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      addauth: { Args: { "": string }; Returns: boolean }
      addgeometrycolumn:
        | {
            Args: {
              catalog_name: string
              column_name: string
              new_dim: number
              new_srid_in: number
              new_type: string
              schema_name: string
              table_name: string
              use_typmod?: boolean
            }
            Returns: string
          }
        | {
            Args: {
              column_name: string
              new_dim: number
              new_srid: number
              new_type: string
              schema_name: string
              table_name: string
              use_typmod?: boolean
            }
            Returns: string
          }
        | {
            Args: {
              column_name: string
              new_dim: number
              new_srid: number
              new_type: string
              table_name: string
              use_typmod?: boolean
            }
            Returns: string
          }
      calculate_risk_score: { Args: { p_user_id: string }; Returns: number }
      check_expired_trials: { Args: never; Returns: undefined }
      disablelongtransactions: { Args: never; Returns: string }
      dropgeometrycolumn:
        | {
            Args: {
              catalog_name: string
              column_name: string
              schema_name: string
              table_name: string
            }
            Returns: string
          }
        | {
            Args: {
              column_name: string
              schema_name: string
              table_name: string
            }
            Returns: string
          }
        | { Args: { column_name: string; table_name: string }; Returns: string }
      dropgeometrytable:
        | {
            Args: {
              catalog_name: string
              schema_name: string
              table_name: string
            }
            Returns: string
          }
        | { Args: { schema_name: string; table_name: string }; Returns: string }
        | { Args: { table_name: string }; Returns: string }
      enablelongtransactions: { Args: never; Returns: string }
      equals: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      generate_thix_uid: { Args: { country_code: string }; Returns: string }
      geometry: { Args: { "": string }; Returns: unknown }
      geometry_above: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_below: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_cmp: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      geometry_contained_3d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_contains: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_contains_3d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_distance_box: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      geometry_distance_centroid: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      geometry_eq: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_ge: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_gt: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_le: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_left: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_lt: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overabove: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overbelow: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overlaps: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overlaps_3d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overleft: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overright: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_right: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_same: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_same_3d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_within: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geomfromewkt: { Args: { "": string }; Returns: unknown }
      get_user_role: { Args: never; Returns: string }
      gettransactionid: { Args: never; Returns: unknown }
      has_permission: { Args: { permission_name: string }; Returns: boolean }
      has_permission_advanced:
        | {
            Args: { permission_name: string; target_user?: string }
            Returns: boolean
          }
        | {
            Args: { required_permission: string; user_id: string }
            Returns: boolean
          }
      insert_audit_log: {
        Args: {
          p_action: string
          p_entity: string
          p_entity_id: string
          p_metadata: Json
        }
        Returns: undefined
      }
      is_admin: { Args: never; Returns: boolean }
      is_admin_or_super: { Args: never; Returns: boolean }
      is_super_admin: { Args: never; Returns: boolean }
      longtransactionsenabled: { Args: never; Returns: boolean }
      pgrst_schema_reload: { Args: never; Returns: undefined }
      populate_geometry_columns:
        | { Args: { tbl_oid: unknown; use_typmod?: boolean }; Returns: number }
        | { Args: { use_typmod?: boolean }; Returns: string }
      postgis_constraint_dims: {
        Args: { geomcolumn: string; geomschema: string; geomtable: string }
        Returns: number
      }
      postgis_constraint_srid: {
        Args: { geomcolumn: string; geomschema: string; geomtable: string }
        Returns: number
      }
      postgis_constraint_type: {
        Args: { geomcolumn: string; geomschema: string; geomtable: string }
        Returns: string
      }
      postgis_extensions_upgrade: { Args: never; Returns: string }
      postgis_full_version: { Args: never; Returns: string }
      postgis_geos_version: { Args: never; Returns: string }
      postgis_lib_build_date: { Args: never; Returns: string }
      postgis_lib_revision: { Args: never; Returns: string }
      postgis_lib_version: { Args: never; Returns: string }
      postgis_libjson_version: { Args: never; Returns: string }
      postgis_liblwgeom_version: { Args: never; Returns: string }
      postgis_libprotobuf_version: { Args: never; Returns: string }
      postgis_libxml_version: { Args: never; Returns: string }
      postgis_proj_version: { Args: never; Returns: string }
      postgis_scripts_build_date: { Args: never; Returns: string }
      postgis_scripts_installed: { Args: never; Returns: string }
      postgis_scripts_released: { Args: never; Returns: string }
      postgis_svn_version: { Args: never; Returns: string }
      postgis_type_name: {
        Args: {
          coord_dimension: number
          geomname: string
          use_new_name?: boolean
        }
        Returns: string
      }
      postgis_version: { Args: never; Returns: string }
      postgis_wagyu_version: { Args: never; Returns: string }
      st_3dclosestpoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_3ddistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_3dintersects: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_3dlongestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_3dmakebox: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_3dmaxdistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_3dshortestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_addpoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_angle:
        | { Args: { line1: unknown; line2: unknown }; Returns: number }
        | {
            Args: { pt1: unknown; pt2: unknown; pt3: unknown; pt4?: unknown }
            Returns: number
          }
      st_area:
        | { Args: { geog: unknown; use_spheroid?: boolean }; Returns: number }
        | { Args: { "": string }; Returns: number }
      st_asencodedpolyline: {
        Args: { geom: unknown; nprecision?: number }
        Returns: string
      }
      st_asewkt: { Args: { "": string }; Returns: string }
      st_asgeojson:
        | {
            Args: { geog: unknown; maxdecimaldigits?: number; options?: number }
            Returns: string
          }
        | {
            Args: { geom: unknown; maxdecimaldigits?: number; options?: number }
            Returns: string
          }
        | {
            Args: {
              geom_column?: string
              maxdecimaldigits?: number
              pretty_bool?: boolean
              r: Record<string, unknown>
            }
            Returns: string
          }
        | { Args: { "": string }; Returns: string }
      st_asgml:
        | {
            Args: {
              geog: unknown
              id?: string
              maxdecimaldigits?: number
              nprefix?: string
              options?: number
            }
            Returns: string
          }
        | {
            Args: { geom: unknown; maxdecimaldigits?: number; options?: number }
            Returns: string
          }
        | { Args: { "": string }; Returns: string }
        | {
            Args: {
              geog: unknown
              id?: string
              maxdecimaldigits?: number
              nprefix?: string
              options?: number
              version: number
            }
            Returns: string
          }
        | {
            Args: {
              geom: unknown
              id?: string
              maxdecimaldigits?: number
              nprefix?: string
              options?: number
              version: number
            }
            Returns: string
          }
      st_askml:
        | {
            Args: { geog: unknown; maxdecimaldigits?: number; nprefix?: string }
            Returns: string
          }
        | {
            Args: { geom: unknown; maxdecimaldigits?: number; nprefix?: string }
            Returns: string
          }
        | { Args: { "": string }; Returns: string }
      st_aslatlontext: {
        Args: { geom: unknown; tmpl?: string }
        Returns: string
      }
      st_asmarc21: { Args: { format?: string; geom: unknown }; Returns: string }
      st_asmvtgeom: {
        Args: {
          bounds: unknown
          buffer?: number
          clip_geom?: boolean
          extent?: number
          geom: unknown
        }
        Returns: unknown
      }
      st_assvg:
        | {
            Args: { geog: unknown; maxdecimaldigits?: number; rel?: number }
            Returns: string
          }
        | {
            Args: { geom: unknown; maxdecimaldigits?: number; rel?: number }
            Returns: string
          }
        | { Args: { "": string }; Returns: string }
      st_astext: { Args: { "": string }; Returns: string }
      st_astwkb:
        | {
            Args: {
              geom: unknown
              prec?: number
              prec_m?: number
              prec_z?: number
              with_boxes?: boolean
              with_sizes?: boolean
            }
            Returns: string
          }
        | {
            Args: {
              geom: unknown[]
              ids: number[]
              prec?: number
              prec_m?: number
              prec_z?: number
              with_boxes?: boolean
              with_sizes?: boolean
            }
            Returns: string
          }
      st_asx3d: {
        Args: { geom: unknown; maxdecimaldigits?: number; options?: number }
        Returns: string
      }
      st_azimuth:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: number }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: number }
      st_boundingdiagonal: {
        Args: { fits?: boolean; geom: unknown }
        Returns: unknown
      }
      st_buffer:
        | {
            Args: { geom: unknown; options?: string; radius: number }
            Returns: unknown
          }
        | {
            Args: { geom: unknown; quadsegs: number; radius: number }
            Returns: unknown
          }
      st_centroid: { Args: { "": string }; Returns: unknown }
      st_clipbybox2d: {
        Args: { box: unknown; geom: unknown }
        Returns: unknown
      }
      st_closestpoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_collect: { Args: { geom1: unknown; geom2: unknown }; Returns: unknown }
      st_concavehull: {
        Args: {
          param_allow_holes?: boolean
          param_geom: unknown
          param_pctconvex: number
        }
        Returns: unknown
      }
      st_contains: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_containsproperly: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_coorddim: { Args: { geometry: unknown }; Returns: number }
      st_coveredby:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_covers:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_crosses: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_curvetoline: {
        Args: { flags?: number; geom: unknown; tol?: number; toltype?: number }
        Returns: unknown
      }
      st_delaunaytriangles: {
        Args: { flags?: number; g1: unknown; tolerance?: number }
        Returns: unknown
      }
      st_difference: {
        Args: { geom1: unknown; geom2: unknown; gridsize?: number }
        Returns: unknown
      }
      st_disjoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_distance:
        | {
            Args: { geog1: unknown; geog2: unknown; use_spheroid?: boolean }
            Returns: number
          }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: number }
      st_distancesphere:
        | { Args: { geom1: unknown; geom2: unknown }; Returns: number }
        | {
            Args: { geom1: unknown; geom2: unknown; radius: number }
            Returns: number
          }
      st_distancespheroid: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_dwithin: {
        Args: {
          geog1: unknown
          geog2: unknown
          tolerance: number
          use_spheroid?: boolean
        }
        Returns: boolean
      }
      st_equals: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_expand:
        | { Args: { box: unknown; dx: number; dy: number }; Returns: unknown }
        | {
            Args: { box: unknown; dx: number; dy: number; dz?: number }
            Returns: unknown
          }
        | {
            Args: {
              dm?: number
              dx: number
              dy: number
              dz?: number
              geom: unknown
            }
            Returns: unknown
          }
      st_force3d: { Args: { geom: unknown; zvalue?: number }; Returns: unknown }
      st_force3dm: {
        Args: { geom: unknown; mvalue?: number }
        Returns: unknown
      }
      st_force3dz: {
        Args: { geom: unknown; zvalue?: number }
        Returns: unknown
      }
      st_force4d: {
        Args: { geom: unknown; mvalue?: number; zvalue?: number }
        Returns: unknown
      }
      st_generatepoints:
        | { Args: { area: unknown; npoints: number }; Returns: unknown }
        | {
            Args: { area: unknown; npoints: number; seed: number }
            Returns: unknown
          }
      st_geogfromtext: { Args: { "": string }; Returns: unknown }
      st_geographyfromtext: { Args: { "": string }; Returns: unknown }
      st_geohash:
        | { Args: { geog: unknown; maxchars?: number }; Returns: string }
        | { Args: { geom: unknown; maxchars?: number }; Returns: string }
      st_geomcollfromtext: { Args: { "": string }; Returns: unknown }
      st_geometricmedian: {
        Args: {
          fail_if_not_converged?: boolean
          g: unknown
          max_iter?: number
          tolerance?: number
        }
        Returns: unknown
      }
      st_geometryfromtext: { Args: { "": string }; Returns: unknown }
      st_geomfromewkt: { Args: { "": string }; Returns: unknown }
      st_geomfromgeojson:
        | { Args: { "": Json }; Returns: unknown }
        | { Args: { "": Json }; Returns: unknown }
        | { Args: { "": string }; Returns: unknown }
      st_geomfromgml: { Args: { "": string }; Returns: unknown }
      st_geomfromkml: { Args: { "": string }; Returns: unknown }
      st_geomfrommarc21: { Args: { marc21xml: string }; Returns: unknown }
      st_geomfromtext: { Args: { "": string }; Returns: unknown }
      st_gmltosql: { Args: { "": string }; Returns: unknown }
      st_hasarc: { Args: { geometry: unknown }; Returns: boolean }
      st_hausdorffdistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_hexagon: {
        Args: { cell_i: number; cell_j: number; origin?: unknown; size: number }
        Returns: unknown
      }
      st_hexagongrid: {
        Args: { bounds: unknown; size: number }
        Returns: Record<string, unknown>[]
      }
      st_interpolatepoint: {
        Args: { line: unknown; point: unknown }
        Returns: number
      }
      st_intersection: {
        Args: { geom1: unknown; geom2: unknown; gridsize?: number }
        Returns: unknown
      }
      st_intersects:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_isvaliddetail: {
        Args: { flags?: number; geom: unknown }
        Returns: Database["public"]["CompositeTypes"]["valid_detail"]
        SetofOptions: {
          from: "*"
          to: "valid_detail"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      st_length:
        | { Args: { geog: unknown; use_spheroid?: boolean }; Returns: number }
        | { Args: { "": string }; Returns: number }
      st_letters: { Args: { font?: Json; letters: string }; Returns: unknown }
      st_linecrossingdirection: {
        Args: { line1: unknown; line2: unknown }
        Returns: number
      }
      st_linefromencodedpolyline: {
        Args: { nprecision?: number; txtin: string }
        Returns: unknown
      }
      st_linefromtext: { Args: { "": string }; Returns: unknown }
      st_linelocatepoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_linetocurve: { Args: { geometry: unknown }; Returns: unknown }
      st_locatealong: {
        Args: { geometry: unknown; leftrightoffset?: number; measure: number }
        Returns: unknown
      }
      st_locatebetween: {
        Args: {
          frommeasure: number
          geometry: unknown
          leftrightoffset?: number
          tomeasure: number
        }
        Returns: unknown
      }
      st_locatebetweenelevations: {
        Args: { fromelevation: number; geometry: unknown; toelevation: number }
        Returns: unknown
      }
      st_longestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_makebox2d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_makeline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_makevalid: {
        Args: { geom: unknown; params: string }
        Returns: unknown
      }
      st_maxdistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_minimumboundingcircle: {
        Args: { inputgeom: unknown; segs_per_quarter?: number }
        Returns: unknown
      }
      st_mlinefromtext: { Args: { "": string }; Returns: unknown }
      st_mpointfromtext: { Args: { "": string }; Returns: unknown }
      st_mpolyfromtext: { Args: { "": string }; Returns: unknown }
      st_multilinestringfromtext: { Args: { "": string }; Returns: unknown }
      st_multipointfromtext: { Args: { "": string }; Returns: unknown }
      st_multipolygonfromtext: { Args: { "": string }; Returns: unknown }
      st_node: { Args: { g: unknown }; Returns: unknown }
      st_normalize: { Args: { geom: unknown }; Returns: unknown }
      st_offsetcurve: {
        Args: { distance: number; line: unknown; params?: string }
        Returns: unknown
      }
      st_orderingequals: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_overlaps: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_perimeter: {
        Args: { geog: unknown; use_spheroid?: boolean }
        Returns: number
      }
      st_pointfromtext: { Args: { "": string }; Returns: unknown }
      st_pointm: {
        Args: {
          mcoordinate: number
          srid?: number
          xcoordinate: number
          ycoordinate: number
        }
        Returns: unknown
      }
      st_pointz: {
        Args: {
          srid?: number
          xcoordinate: number
          ycoordinate: number
          zcoordinate: number
        }
        Returns: unknown
      }
      st_pointzm: {
        Args: {
          mcoordinate: number
          srid?: number
          xcoordinate: number
          ycoordinate: number
          zcoordinate: number
        }
        Returns: unknown
      }
      st_polyfromtext: { Args: { "": string }; Returns: unknown }
      st_polygonfromtext: { Args: { "": string }; Returns: unknown }
      st_project: {
        Args: { azimuth: number; distance: number; geog: unknown }
        Returns: unknown
      }
      st_quantizecoordinates: {
        Args: {
          g: unknown
          prec_m?: number
          prec_x: number
          prec_y?: number
          prec_z?: number
        }
        Returns: unknown
      }
      st_reduceprecision: {
        Args: { geom: unknown; gridsize: number }
        Returns: unknown
      }
      st_relate: { Args: { geom1: unknown; geom2: unknown }; Returns: string }
      st_removerepeatedpoints: {
        Args: { geom: unknown; tolerance?: number }
        Returns: unknown
      }
      st_segmentize: {
        Args: { geog: unknown; max_segment_length: number }
        Returns: unknown
      }
      st_setsrid:
        | { Args: { geog: unknown; srid: number }; Returns: unknown }
        | { Args: { geom: unknown; srid: number }; Returns: unknown }
      st_sharedpaths: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_shortestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_simplifypolygonhull: {
        Args: { geom: unknown; is_outer?: boolean; vertex_fraction: number }
        Returns: unknown
      }
      st_split: { Args: { geom1: unknown; geom2: unknown }; Returns: unknown }
      st_square: {
        Args: { cell_i: number; cell_j: number; origin?: unknown; size: number }
        Returns: unknown
      }
      st_squaregrid: {
        Args: { bounds: unknown; size: number }
        Returns: Record<string, unknown>[]
      }
      st_srid:
        | { Args: { geog: unknown }; Returns: number }
        | { Args: { geom: unknown }; Returns: number }
      st_subdivide: {
        Args: { geom: unknown; gridsize?: number; maxvertices?: number }
        Returns: unknown[]
      }
      st_swapordinates: {
        Args: { geom: unknown; ords: unknown }
        Returns: unknown
      }
      st_symdifference: {
        Args: { geom1: unknown; geom2: unknown; gridsize?: number }
        Returns: unknown
      }
      st_symmetricdifference: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_tileenvelope: {
        Args: {
          bounds?: unknown
          margin?: number
          x: number
          y: number
          zoom: number
        }
        Returns: unknown
      }
      st_touches: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_transform:
        | {
            Args: { from_proj: string; geom: unknown; to_proj: string }
            Returns: unknown
          }
        | {
            Args: { from_proj: string; geom: unknown; to_srid: number }
            Returns: unknown
          }
        | { Args: { geom: unknown; to_proj: string }; Returns: unknown }
      st_triangulatepolygon: { Args: { g1: unknown }; Returns: unknown }
      st_union:
        | { Args: { geom1: unknown; geom2: unknown }; Returns: unknown }
        | {
            Args: { geom1: unknown; geom2: unknown; gridsize: number }
            Returns: unknown
          }
      st_voronoilines: {
        Args: { extend_to?: unknown; g1: unknown; tolerance?: number }
        Returns: unknown
      }
      st_voronoipolygons: {
        Args: { extend_to?: unknown; g1: unknown; tolerance?: number }
        Returns: unknown
      }
      st_within: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_wkbtosql: { Args: { wkb: string }; Returns: unknown }
      st_wkttosql: { Args: { "": string }; Returns: unknown }
      st_wrapx: {
        Args: { geom: unknown; move: number; wrap: number }
        Returns: unknown
      }
      thix_check_admin: { Args: never; Returns: boolean }
      thix_is_admin:
        | { Args: never; Returns: boolean }
        | { Args: { min_level?: number }; Returns: boolean }
      thix_request_profile_access: {
        Args: {
          p_message?: string
          p_target_user_id: string
          p_thix_id?: string
        }
        Returns: string
      }
      thix_role_level: { Args: { role: string }; Returns: number }
      thix_set_access_request_status: {
        Args: { p_new_status: string; p_request_id: string }
        Returns: undefined
      }
      unlockrows: { Args: { "": string }; Returns: number }
      updategeometrysrid: {
        Args: {
          catalogn_name: string
          column_name: string
          new_srid_in: number
          schema_name: string
          table_name: string
        }
        Returns: string
      }
    }
    Enums: {
      user_role:
        | "super_admin"
        | "admin"
        | "moderator"
        | "university_partner"
        | "recruiter"
        | "institution"
        | "support_agent"
    }
    CompositeTypes: {
      geometry_dump: {
        path: number[] | null
        geom: unknown
      }
      valid_detail: {
        valid: boolean | null
        reason: string | null
        location: unknown
      }
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      user_role: [
        "super_admin",
        "admin",
        "moderator",
        "university_partner",
        "recruiter",
        "institution",
        "support_agent",
      ],
    },
  },
} as const

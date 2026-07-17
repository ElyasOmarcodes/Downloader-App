package com.elyasomar.apksigner.di

import com.elyasomar.apksigner.data.repository.SigningRepositoryImpl
import com.elyasomar.apksigner.domain.repository.SigningRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindSigningRepository(impl: SigningRepositoryImpl): SigningRepository
}
